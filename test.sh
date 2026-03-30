#!/usr/bin/env zsh

# Guard: require Lua 5.2 to match the Factorio 2.x runtime.
lua_version=$(lua -e "print(_VERSION)")
if [[ "$lua_version" != "Lua 5.2" ]]; then
  echo "Error: expected Lua 5.2, got $lua_version" >&2
  echo "Run: luaver use 5.2.4" >&2
  exit 1
fi

# Just run all test files.
lua test/helpers_test.lua
