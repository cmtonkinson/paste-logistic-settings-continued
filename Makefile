.PHONY: clean deps format lint test factestio verify

ROCKSPEC := $(lastword $(sort $(wildcard *.rockspec)))

clean:
	rm -rf factestio/results/*

deps:
	luarocks install --only-deps "$(ROCKSPEC)"
	luarocks test --prepare "$(ROCKSPEC)"
	@echo ""
	@echo "Note: stylua must be installed separately:"
	@echo "  brew install stylua"

format:
	stylua .

lint:
	luacheck .

test:
	busted -o gtest

factestio:
	factestio

verify: format lint test
ifndef CI
	$(MAKE) factestio
endif
