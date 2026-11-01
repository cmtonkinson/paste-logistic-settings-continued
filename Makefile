.PHONY: clean deps factestio format format-check help lint major minor patch release test verify

ROCKSPEC := $(lastword $(sort $(wildcard *.rockspec)))
LUA_VERSION := $(shell cat .lua-version)
FACTESTIO_TIMEOUT ?= 10

# Project-local Lua toolchain, called by absolute path so targets need no shell
# setup. Override HEREROCKS when hererocks is not run through uvx.
LUA_TREE := .hererocks
LUA_BIN := $(CURDIR)/$(LUA_TREE)/bin
HEREROCKS ?= uvx hererocks
LUAROCKS := $(LUA_BIN)/luarocks
LUACHECK := $(LUA_BIN)/luacheck
BUSTED := $(LUA_BIN)/busted

clean: ## Delete factestio results
	rm -rf factestio_results/*

$(LUAROCKS):
	$(HEREROCKS) $(LUA_TREE) --lua $(LUA_VERSION) --luarocks latest --no-readline

deps: $(LUAROCKS) ## Build the local Lua toolchain and install dev dependencies
	$(LUAROCKS) install --only-deps "$(ROCKSPEC)"
	$(LUAROCKS) test --prepare "$(ROCKSPEC)"
	@echo ""
	@echo "Note: stylua must be installed separately:"
	@echo "  brew install stylua"

format: ## Rewrite files with stylua
	stylua .

format-check: ## Check formatting without rewriting
	stylua --check .

lint: ## Run luacheck
	$(LUACHECK) .

test: ## Run unit tests
	$(BUSTED) -o gtest

# factestio resolves `lua` and `luarocks` from PATH and requires Lua 5.2.
factestio: ## Run the factestio integration suite against real Factorio
	PATH="$(LUA_BIN):$$PATH" factestio --timeout $(FACTESTIO_TIMEOUT)

verify: format-check lint test ## Run format-check, lint, test, then factestio (skipped in CI)
ifndef CI
	$(MAKE) factestio
endif

release: ## Cut a release: make release <major|minor|patch>
	scripts/release.sh --$(word 2,$(MAKECMDGOALS))

# Bump levels are positional arguments to `release`; on their own they do nothing.
major minor patch:
	@:

help: ## Show available targets
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F ':.*## ' '{printf "  %-13s %s\n", $$1, $$2}'
