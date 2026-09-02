# ted

A fully modular text editor on the BEAM, written in LFE.

Every editor subsystem -- buffers, file I/O, the command table, keymaps,
configuration -- is a plugin mounted onto a runtime at startup. Nothing is
hard-wired: capability is added by mounting another plugin, and plugins
discover each other by scanning a registry rather than through a fixed
API.

It is built on two standalone libraries:

- [patchbay](https://github.com/takeiteasy/patchbay) -- a Cordis-inspired
  plugin/service runtime core (supervised contexts, services with
  mount-order-independent dependency injection, a race-free registry,
  dynamic sub-process supervision). This is ted's module system.
- [lasso](https://github.com/takeiteasy/lasso) -- a persistent rope for
  editor text: `O(log n)` edits, `O(1)` length/line-count, codepoint
  to line/column mapping. This is ted's buffer representation, and its
  structural sharing makes undo history nearly free.

This phase is the **core only** -- there is no user interface yet. See
[docs/architecture.md](docs/architecture.md) for the design,
[docs/plugins.md](docs/plugins.md) for the plugin contract, and
[docs/getting-started.md](docs/getting-started.md) for building and
running the vertical-slice demo in `src/demo/`.

Issues: `~takeiteasy/ted` on sourcehut.

## License

GPLv3, see [LICENSE](LICENSE).
