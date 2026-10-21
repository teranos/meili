.PHONY: build install clean

PREFIX ?= $(HOME)/.qntx
BIN := target/release/qntx-meili

# Restart — tell running QNTX to hot-restart meili. Silent no-op if QNTX isn't running.
define restart-plugin
	@PORT=$${BACKEND_PORT:-8770}; \
	 curl -sf -X POST http://127.0.0.1:$$PORT/api/plugins/meili/restart > /dev/null 2>&1 \
		&& echo "  ↻ LOADED — meili restarted, live at http://127.0.0.1:$$PORT" \
		|| echo "  ⊘ NOT LOADED — no QNTX answers at http://127.0.0.1:$$PORT, binary is built but not active"
endef

build: ## Build qntx-meili release binary
	@cargo build --release
	@echo "✓ $(BIN)"

install: build ## Build, install, and restart qntx-meili plugin
	@mkdir -p $(PREFIX)/plugins
	@cp $(BIN) $(PREFIX)/plugins/qntx-meili
	@chmod +x $(PREFIX)/plugins/qntx-meili
	@codesign -s - --force $(PREFIX)/plugins/qntx-meili
	@echo "✓ BUILD OK — binary installed to $(PREFIX)/plugins/qntx-meili"
	$(call restart-plugin)

clean: ## Clean build artifacts
	@cargo clean
