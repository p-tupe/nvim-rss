.PHONY: test clean install-deps lint help

test:
	@echo "Running all tests..."
	@busted --pattern=_spec%.lua$

clean:
	@echo "Cleaning test artifacts..."
	@rm -rf /tmp/nvim_rss_test*
	@rm -f luacov.*.out

install-deps:
	@echo "Installing test dependencies..."
	@luarocks install busted || echo "busted already installed"
	@luarocks install luacov || echo "luacov already installed"

lint:
	@echo "Running linter..."
	@luacheck lua/ tests/ || echo "Install luacheck for linting: luarocks install luacheck"

help:
	@echo "Available targets:"
	@echo "  make test          - Run all tests"
	@echo "  make clean         - Clean test artifacts"
	@echo "  make install-deps  - Install test dependencies"
	@echo "  make lint          - Run linter (requires luacheck)"
	@echo "  make help          - Show this help"
