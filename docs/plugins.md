# Writing a ted plugin

A ted subsystem -- and any third-party extension -- is a
`patchbay_service` callback module mounted onto the `'ted-root` context.
patchbay handles registry registration and dependency-waiting; the plugin
supplies behaviour. Because the contract is plain atoms, tuples and maps,
a plugin can be written in any BEAM language.

The full patchbay plugin contract is documented in the
[patchbay repo](https://github.com/takeiteasy/patchbay/tree/trunk/docs/plugins.md).
This page covers what is specific to ted. `src/demo/ted-demo-service.lfe`
is a complete, minimal example.

## The callback set

```
service_name()                -> atom                            [required]
dependencies()                -> [atom()]                        [required]
init(Args)                    -> {ok, State}                     [required]
metadata()                    -> map()                           [optional]
ready(Deps, State)            -> {ok, State}                     [optional]
dep_down(Name, Reason, State) -> {ok, State}                     [optional]
handle_message(Msg, State)    -> {ok, State} | {reply, R, State} [optional]
terminate(Reason, State)      -> ok                              [optional]
```

A plugin with no dependencies needs only `service_name/0`,
`dependencies/0` (returning `'()`), and `init/1`; it goes `ready` in
`init/1`.

## The child spec

Each plugin writes its own `child_spec`, matching whatever arity `init/1`
needs:

```lfe
(defun child_spec ()
  `#m(id ted-demo
      start #(patchbay_service start_link (ted-demo-service #m()))
      restart transient
      shutdown 5000
      type worker
      modules (patchbay_service)))
```

Mount it with `(patchbay_context:mount ctx (your-module:child_spec ...))`,
where `ctx` is the `'ted-root` pid from
`(patchbay_registry:lookup 'ted-root)`. `restart transient` is the
default; buffer agents override to `temporary` (see
[architecture.md](architecture.md)).

## metadata/0 and the `kind` convention

ted has no central registry of subsystems. `metadata/0` is published as
the registration's props, and ted requires a `kind` key so callers can
find plugin families by scanning `patchbay_registry:names/0` and filtering
`lookup/1` results on `kind`. Kinds ted recognises:

| `kind` | what it is |
|---|---|
| `ted-demo` | the vertical-slice example plugin |
| `buffer-manager` | the service that opens, closes and lists buffers |
| `buffer` | one open buffer (a `patchbay_agent`, dynamically named) |
| `file` | file load / save and encoding handling |
| `command` | one registered editor command |
| `keymap` | a keymap layer |
| `config` | the `~/.ted/init.lfe` evaluator and plugin loader |

A new family just picks a new `kind` string; no registry code changes.

## Talking to a plugin

`(patchbay_service:call_service name msg)` and `(... cast name msg)`
forward to `handle_message/2`. **Use the three-argument
`call_service/3` with an explicit timeout** for anything that touches a
whole buffer -- `lasso:to_binary/1` and `lasso:validate/1` are `O(n)`, and
`call_service/2`'s 5 s default will crash the caller on a large file while
the plugin keeps running.

## The disposer

`terminate/2` is where you release whatever `init/1` acquired (an open
file handle, a registration in another service's table). It runs before
patchbay unregisters the plugin, so it is also the place to send a final
notification. It only runs because `patchbay_service` traps exits for you.
