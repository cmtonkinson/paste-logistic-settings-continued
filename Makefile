.PHONY: clean deps factestio format format-check lint test verify

ROCKSPEC := $(lastword $(sort $(wildcard *.rockspec)))
LUA_VERSION := $(shell cat .lua-version)
FACTESTIO_TIMEOUT ?= 10

# Project-local Lua toolchain, built by hererocks into $(LUA_TREE). Nothing here
# depends on the ambient shell, so every target works from a cold shell. Override
# HEREROCKS when it is not run through uvx; CI installs it and passes HEREROCKS=hererocks.
LUA_TREE := .hererocks
HEREROCKS ?= uvx hererocks
LUAROCKS := $(LUA_TREE)/bin/luarocks
LUACHECK := $(LUA_TREE)/bin/luacheck
BUSTED := $(LUA_TREE)/bin/busted

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

factestio:
	factestio --timeout $(FACTESTIO_TIMEOUT)

verify: format-check lint test
ifndef CI
	$(MAKE) factestio
endif
