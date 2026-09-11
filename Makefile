DEMO_NAME := TextExtractorDemo
DEMO_DIR := Examples/$(DEMO_NAME)
DEMO_PROJECT := $(DEMO_DIR)/$(DEMO_NAME).xcodeproj
MAC_SCHEME := $(DEMO_NAME)-macOS
IOS_SCHEME := $(DEMO_NAME)-iOS
MAC_DERIVED_DATA ?= $(HOME)/Developer/tmp/$(DEMO_NAME)-macOS-DerivedData
IOS_DERIVED_DATA ?= $(HOME)/Developer/tmp/$(DEMO_NAME)-iOS-DerivedData
MAC_APP := $(MAC_DERIVED_DATA)/Build/Products/Debug/$(DEMO_NAME).app

.PHONY: demo generate build open ios-build clean

demo: build open

generate:
	@command -v xcodegen >/dev/null || { echo "XcodeGen is required: brew install xcodegen"; exit 1; }
	cd "$(DEMO_DIR)" && xcodegen generate

build: generate
	xcodebuild \
		-scheme $(MAC_SCHEME) \
		-project $(DEMO_PROJECT) \
		-destination 'platform=macOS' \
		-derivedDataPath $(MAC_DERIVED_DATA) \
		CODE_SIGNING_ALLOWED=NO \
		build

open:
	@test -d "$(MAC_APP)" || { \
		echo "Demo app not found. Run 'make build' first."; \
		exit 1; \
	}
	@if pgrep -x "$(DEMO_NAME)" >/dev/null; then \
		pkill -x "$(DEMO_NAME)"; \
		attempt=0; \
		while pgrep -x "$(DEMO_NAME)" >/dev/null && [ $$attempt -lt 50 ]; do \
			sleep 0.1; \
			attempt=$$((attempt + 1)); \
		done; \
	fi
	open -n "$(MAC_APP)"

ios-build: generate
	xcodebuild \
		-scheme $(IOS_SCHEME) \
		-project $(DEMO_PROJECT) \
		-destination 'generic/platform=iOS Simulator' \
		-derivedDataPath $(IOS_DERIVED_DATA) \
		CODE_SIGNING_ALLOWED=NO \
		build

clean:
	rm -rf "$(MAC_DERIVED_DATA)" "$(IOS_DERIVED_DATA)"
	rm -rf "$(DEMO_PROJECT)"
