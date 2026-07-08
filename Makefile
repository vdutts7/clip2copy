# clip2copy - auto-copy macOS screenshots to clipboard

BINARY = clip2copy
SOURCES = Sources/clip2copy.swift
BUILD_DIR = bin
WATCH_SCRIPT = scripts/clip2copy-watch.sh

.PHONY: build build-fast install install-user install-watch service-start service-stop test test-setup-prompt clean

build:
	@echo "Building $(BINARY) (universal)..."
	@mkdir -p $(BUILD_DIR)
	swiftc -O -target arm64-apple-macos12 -o $(BUILD_DIR)/$(BINARY)-arm64 $(SOURCES)
	swiftc -O -target x86_64-apple-macos12 -o $(BUILD_DIR)/$(BINARY)-x86_64 $(SOURCES)
	lipo -create -output $(BUILD_DIR)/$(BINARY) $(BUILD_DIR)/$(BINARY)-arm64 $(BUILD_DIR)/$(BINARY)-x86_64
	@rm -f $(BUILD_DIR)/$(BINARY)-arm64 $(BUILD_DIR)/$(BINARY)-x86_64
	@echo "Built: $(BUILD_DIR)/$(BINARY)"

build-fast:
	@mkdir -p $(BUILD_DIR)
	swiftc -O -o $(BUILD_DIR)/$(BINARY) $(SOURCES)
	@echo "Built: $(BUILD_DIR)/$(BINARY)"

install: build-fast
	@mkdir -p $(HOME)/.local/bin
	@cp $(BUILD_DIR)/$(BINARY) $(HOME)/.local/bin/$(BINARY)
	@chmod +x $(HOME)/.local/bin/$(BINARY)
	@echo "Installed $(HOME)/.local/bin/$(BINARY)"

install-watch: install
	@mkdir -p $(HOME)/.local/bin
	@cp $(WATCH_SCRIPT) $(HOME)/.local/bin/clip2copy-watch
	@chmod +x $(HOME)/.local/bin/clip2copy-watch
	@echo "Installed $(HOME)/.local/bin/clip2copy-watch"
	@echo "Run: CLIP2COPY_BIN=$$HOME/.local/bin/clip2copy clip2copy-watch"

install-user: install

service-start:
	@CLIP2COPY_BIN=$$(command -v clip2copy || echo $(HOME)/.local/bin/clip2copy) \
	  CLIP2COPY_FSWATCH=$$(command -v fswatch) \
	  nohup $(HOME)/.local/bin/clip2copy-watch >/tmp/clip2copy.log 2>/tmp/clip2copy.err &
	@echo "Started clip2copy-watch (see /tmp/clip2copy.log)"

service-stop:
	@pkill -f clip2copy-watch || true
	@echo "Stopped clip2copy-watch"

test: build-fast test-setup-prompt
	@$(BUILD_DIR)/$(BINARY) --version
	@$(BUILD_DIR)/$(BINARY) --help >/dev/null
	@$(BUILD_DIR)/$(BINARY) config show >/dev/null
	@$(BUILD_DIR)/$(BINARY) status >/dev/null

test-setup-prompt:
	@zsh scripts/test-setup-prompt.zsh

clean:
	@rm -rf $(BUILD_DIR)
	@echo "Cleaned"
