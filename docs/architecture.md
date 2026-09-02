# Architecture

ted is a text editor assembled from plugins. The editor process tree is a
[patchbay](https://github.com/takeiteasy/patchbay) context with editor
subsystems mounted onto it; each subsystem is a `patchbay_service`
callback module. Text lives in a [lasso](https://github.com/takeiteasy/lasso)
rope.

## The tree

```
ted-app  (application behaviour)
  |
  +-- ted-sup  ==  patchbay_context 'ted-root
        |
        +-- patchbay_agent_sup 'ted-buffer-sup   (supervisor, dynamic buffers)
        |     +-- 'buffer-1   patchbay_agent  (lasso rope + undo history)
        |     +-- 'buffer-N   ...
        |
        +-- ted-buffer-manager   service   open / close / list buffers
        +-- ted-file             service   load / save, encoding, line endings
        +-- ted-command          service   command registry + dispatch
        +-- ted-keymap           service   key event -> command
        +-- ted-config           service   evaluate ~/.ted/init.lfe, mount plugins
```

Only `ted-app` and `ted-sup` exist today. Everything below `ted-root` is
mounted at runtime and is introduced subsystem by subsystem; the demo
plugin in `src/demo/` stands in for a real subsystem for now.

## Why the root is a context, not a supervisor

A top-level context is not a special case -- it is the same primitive
every nested context uses. `ted-sup:start_link/0` is a one-liner that
starts `patchbay_context` under the name `'ted-root`. Subsystems mount
onto it with `patchbay_context:mount/2`; a subsystem that itself composes
children mounts a nested context. There is no hand-rolled supervisor
module anywhere in ted.

## Discovery is by registry scan

There is no central "list of buffers" or "list of commands" API. Each
service publishes a `metadata/0` map that patchbay stores as its registry
props, always including a `kind` key (`#m(kind buffer ...)`,
`#m(kind command ...)`). A caller that wants every command walks
`patchbay_registry:names/0` and `patchbay_registry:lookup/1`, keeping the
entries whose props have `kind == command`. New plugin families work the
same way with no change to any registry code.

## Buffers are one process each

`patchbay_service:service_name/0` takes no arguments, so one service
module owns exactly one registry name -- it cannot stand in for N open
buffers. Instead a buffer is a `patchbay_agent`: `patchbay_agent_sup` is a
`simple_one_for_one` that spawns them, and each is registered under a
dynamic name (`'buffer-1`, `'buffer-2`, ...) via the agent's
`#{name => ...}` option. `ted-buffer-manager` allocates the names and
holds the `patchbay_agent_sup` handle.

The agent supervisor is mounted as a **sibling** of `ted-buffer-manager`
on `ted-root`, not as its child: a `patchbay_service` is a gen_server and
cannot supervise processes. It also has to be this way for crash
reporting -- `patchbay_agent_sup:delegate/5` calls
`erlang:monitor(process, Pid)` from the caller, so the manager must be the
one that calls `delegate/5` to receive the buffer's `DOWN`.

Buffer agents are `restart => temporary`: a crashed buffer stays gone. An
automatic restart would produce an *empty* buffer and silently drop the
file's unsaved edits, which is worse than surfacing the failure. The
manager hears the `DOWN` and drops the buffer from its table.

## Undo comes from the rope, not from ted

lasso ropes are persistent and share structure between versions, so a
buffer's undo history is just a list of previous rope values. There is no
diff format and no inverse-operation machinery to build -- taking a
snapshot before an edit is `O(1)` in the shared case. This is the main
reason ted is built on lasso.

## Addressing a buffer

`patchbay_agent:handle_call/3` matches the same `{msg, Msg}` envelope that
`patchbay_service:call_service/3` sends, so a buffer is called by its
registry name exactly like a service:
`(patchbay_service:call_service 'buffer-1 msg timeout-ms)`. Prefer this
over the agent's `prompt_wait/2`, which needs a raw pid and uses
gen_server's 5 s default timeout.

## Hazards

- `patchbay_service:call_service/2` uses gen_server's 5 s default
  timeout. Any `O(n)` rope operation (`lasso:to_binary/1`,
  `lasso:validate/1` on a large buffer) must go through `call_service/3`
  with an explicit timeout, or the caller crashes while the buffer keeps
  running.
- lasso indices are **codepoints, not grapheme clusters**. Combining
  marks and emoji ZWJ sequences span several codepoints, so cursor
  movement needs a layer above lasso -- it is not something the rope
  gives you.
- `patchbay_context:start_link/2` returns an *unnamed* supervisor pid;
  the context self-registers under its name during init, so hold the pid
  or look it up with `patchbay_registry:lookup/1`.
- The patchbay registry is a hard-coded singleton name, so only one
  patchbay application runs per BEAM node -- and test suites must
  serialize around it.

## The event bus is upstream

An editor needs hooks -- `before-save` (veto-able), `after-change`
(fire-and-forget), mode hooks. patchbay does not have a topic event bus
yet; its docs list one as deferred work. Rather than build an
editor-shaped bus inside ted, the bus is being added to patchbay so every
consumer benefits, and ted's hook layer will sit on top of it.
