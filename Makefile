.PHONY: clean deps factestio format format-check lint test verify

ROCKSPEC := $(lastword $(sort $(wildcard *.rockspec)))
LUA_VERSION := $(shell cat .lua-version)
FACTESTIO_TIMEOUT ?= 10

# Project-local Lua toolchain, built by hererocks into $(LUA_TREE). Nothing here
# depends on the ambient shell, so every target works from a cold shell. Override
# HEREROCKS when it is not run through uvx; CI installs it and passes HEREROCKS=hererocks.
LUA_TREE := .hererocks
LUA_BIN := $(CURDIR)/$(LUA_TREE)/bin
HEREROCKS ?= uvx hererocks
LUAROCKS := $(LUA_BIN)/luarocks
LUACHECK := $(LUA_BIN)/luacheck
BUSTED := $(LUA_BIN)/busted

clean:
	rm -rf factestio/results/*

$(LUAROCKS):
	$(HEREROCKS) $(LUA_TREE) --lua $(LUA_VERSION) --luarocks latest --no-readline

deps: $(LUAROCKS)
	$(LUAROCKS) install --only-deps "$(ROCKSPEC)"
	$(LUAROCKS) test --prepare "$(ROCKSPEC)"
	@echo ""
	@echo "Note: stylua must be installed separately:"
	@echo "  brew install stylua"

format:
	stylua .

format-check:
	stylua --check .

lint:
	$(LUACHECK) .

test:
	$(BUSTED) -o gtest

# factestio is an external wrapper that resolves `lua` and `luarocks` from PATH
# and requires Lua 5.2, so it needs the project toolchain ahead of the ambient one.
# Depends on clean because Factorio embeds the scenario directory -- and thus
# factestio/results/ -- into every save it writes, so stale results from a prior
# run get baked into this run's saves. See README.
factestio: clean
	PATH="$(LUA_BIN):$$PATH" factestio --timeout $(FACTESTIO_TIMEOUT)

verify: format-check lint test
ifndef CI
	$(MAKE) factestio
endif
