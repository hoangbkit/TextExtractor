MAC_DEMO_NAME := TextExtractorDemo
MAC_DEMO_DIR := Examples/$(MAC_DEMO_NAME)
MAC_DEMO_PROJECT := $(MAC_DEMO_DIR)/$(MAC_DEMO_NAME).xcodeproj
MAC_DEMO_SCHEME := $(MAC_DEMO_NAME)
MAC_DEMO_DERIVED_DATA ?= $(HOME)/Developer/tmp/$(MAC_DEMO_NAME)DerivedData
MAC_DEMO_APP := $(MAC_DEMO_DERIVED_DATA)/Build/Products/Debug/$(MAC_DEMO_NAME).app

IOS_DEMO_NAME := TextExtractorIOSDemo
IOS_DEMO_DIR := Examples/$(IOS_DEMO_NAME)
IOS_DEMO_PROJECT := $(IOS_DEMO_DIR)/$(IOS_DEMO_NAME).xcodeproj
IOS_DEMO_DERIVED_DATA ?= $(HOME)/Developer/tmp/$(IOS_DEMO_NAME)DerivedData

.PHONY: demo build open generate ios-generate ios-build clean

demo: build open

generate:
	@command -v xcodegen >/dev/null || { echo "XcodeGen is required: brew install xcodegen"; exit 1; }
	cd "$(MAC_DEMO_DIR)" && xcodegen generate

build: generate
	xcodebuild \
		-scheme $(MAC_DEMO_SCHEME) \
		-project $(MAC_DEMO_PROJECT) \
		-destination 'platform=macOS' \
		-derivedDataPath $(MAC_DEMO_DERIVED_DATA) \
		CODE_SIGNING_ALLOWED=NO \
		build

open:
	@test -d "$(MAC_DEMO_APP)" || { \
		echo "Demo app not found. Run 'make build' first."; \
		exit 1; \
	}
	@if pgrep -x "$(MAC_DEMO_SCHEME)" >/dev/null; then \
		pkill -x "$(MAC_DEMO_SCHEME)"; \
		attempt=0; \
		while pgrep -x "$(MAC_DEMO_SCHEME)" >/dev/null && [ $$attempt -lt 50 ]; do \
			sleep 0.1; \
			attempt=$$((attempt + 1)); \
		done; \
	fi
	open -n "$(MAC_DEMO_APP)"

ios-generate:
	@command -v xcodegen >/dev/null || { echo "XcodeGen is required: brew install xcodegen"; exit 1; }
	cd "$(IOS_DEMO_DIR)" && xcodegen generate

ios-build: ios-generate
	xcodebuild \
		-scheme $(IOS_DEMO_NAME) \
		-project $(IOS_DEMO_PROJECT) \
		-destination 'generic/platform=iOS Simulator' \
		-derivedDataPath $(IOS_DEMO_DERIVED_DATA) \
		CODE_SIGNING_ALLOWED=NO \
		build

clean:
	rm -rf "$(MAC_DEMO_DERIVED_DATA)" "$(IOS_DEMO_DERIVED_DATA)"
	rm -rf "$(MAC_DEMO_PROJECT)" "$(IOS_DEMO_PROJECT)"
