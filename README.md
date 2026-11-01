*A lightweight Factorio 2.1 mod to save a few clicks when creating bot-operated
crafting machines.*

See ./description.md, which mirrors the mod portal page; keep the two in sync.

# Development
`make deps` builds the Lua version Factorio embeds, pinned in `.lua-version`,
into `.hererocks/` with [hererocks], then installs the dev and test
dependencies. It needs [uv] (for `uvx`) and a C compiler, but no system Lua.
Set `HEREROCKS` to invoke hererocks other than through `uvx`. Delete
`.hererocks/` to force a clean rebuild.
```sh
make deps
```

Install `stylua` separately: `brew install stylua`.

`make verify` runs format checking, linting, tests, then the `factestio`
integration suite. When `CI` is set it skips `factestio`, which CI runs as its
own `integration` job. `make format` rewrites files; `make help` lists targets.

`make` targets call the toolchain by absolute path. To run the tools directly,
put `.hererocks/bin/` first on `PATH`: `factestio` resolves `lua` from `PATH`
and refuses anything but 5.2. The `.envrc` does this under [direnv] after a
one-time `direnv allow`; otherwise:
```sh
export PATH="$PWD/.hererocks/bin:$PATH"
```

`make factestio` drives a real Factorio install. Install
`brew install cmtonkinson/tap/factestio` 0.7.0 or later (earlier releases exit
0 when tests fail), then run `factestio activate` once here. Activation
scaffolds the gitignored `factestio/config.lua`, symlinks the mod into
Factorio's data directory, and rewrites `mod-list.json` to disable other mods;
`factestio deactivate` restores them. `factestio doctor` checks the environment.

[direnv]: https://direnv.net
[hererocks]: https://github.com/luarocks/hererocks
[uv]: https://docs.astral.sh/uv/
