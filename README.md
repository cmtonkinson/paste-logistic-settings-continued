*A lightweight Factorio 2.0 mod to save a few clicks when creating bot-operated
crafting machines.*

Read ./description.md for more information; this is meant to stay in sync with
what's on the mod portal.

# Development
This project targets Lua 5.2, the version Factorio embeds, pinned in
`.lua-version`. `make deps` builds exactly that toolchain into
`.hererocks/` with [hererocks] and installs the dev & test dependencies. It
needs no system Lua and no shell setup, so it works from a cold shell in a
fresh clone:
```sh
make deps
```

This requires [uv], for `uvx`, and a C compiler. Set `HEREROCKS` to change how
hererocks is invoked; CI installs it directly and passes `HEREROCKS=hererocks`.

`make verify` runs format checking, linting, and tests, then the `factestio`
integration suite; CI sets `CI`, which skips that last step. Everything before
it runs identically in both places. `make format` rewrites files rather than
only checking them.

`stylua` is not a LuaRocks package and must be installed separately with
`brew install stylua`.

Delete `.hererocks/` to force a clean rebuild of the toolchain.

[hererocks]: https://github.com/luarocks/hererocks
[uv]: https://docs.astral.sh/uv/
