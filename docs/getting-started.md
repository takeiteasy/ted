# Getting started

ted is a modular text editor core. The plugin runtime it builds on lives
in its own repo,
[patchbay](https://github.com/takeiteasy/patchbay); the rope lives in
[lasso](https://github.com/takeiteasy/lasso). See those repos for the
runtime and buffer-representation details.

## Toolchain

- Erlang/OTP (developed against OTP 29 / ERTS 17.0.5)
- [rebar3](https://rebar3.org/)

Everything else (`patchbay`, `lasso`, `lfe`, `rebar3_lfe`, `ltest`) is
pulled by `rebar.config`; no global LFE install is required.

## Build

```sh
rebar3 compile
```

Fetches patchbay and lasso (`trunk` branch) plus the LFE toolchain, and
compiles ted.

## Test

```sh
rebar3 as test ltest
```

Runs `ted-demo-tests`: the application boots, its root is a discoverable
`patchbay_context` registered as `'ted-root`, a plugin mounts onto it and
is found by a registry scan on its `metadata/0`, and lasso is linked in
and usable.

`ltest` discovers suites by scanning compiled beams for the `ltest-unit`
behaviour tag, not by the presence of `deftest` forms -- a test module
needs `(behaviour ltest-unit)` in its `defmodule` or `ltest` silently
reports "no unit tests found".

If a cold `rebar3 as test ltest` fails with `lfe_comp not found` while
compiling ltest's own sources, run plain `rebar3 compile` once first, then
retry.

## Run the vertical-slice demo

```sh
rebar3 shell
```

Then, from the Erlang shell:

```erlang
application:ensure_all_started(ted).
{ok, {Ctx, _}} = patchbay_registry:lookup('ted-root').
patchbay_context:mount(Ctx, 'ted-demo-service':child_spec()).
patchbay_registry:names().                       %% 'ted-demo' is listed
{ok, {_Pid, Props}} = patchbay_registry:lookup('ted-demo').
maps:get(kind, Props).                            %% => ted-demo
patchbay_service:call_service('ted-demo', {echo, <<"hi">>}, 5000).
%% => {ok, <<"hi">>}
```

lasso is available in the same shell:

```erlang
lasso:line_count(lasso:from_binary(<<"a\nb\nc">>)).   %% => 3
```

(The Erlang shell needs quoted module atoms -- `'ted-demo-service'`,
`'ted-demo'` -- because the names contain hyphens.)

This is the whole point of the skeleton: a subsystem is mounted onto the
root context at runtime, registers itself, and is found by other code
through a registry scan rather than a compiled-in list. Every real editor
subsystem follows this shape -- see [plugins.md](plugins.md).
