DEMO_NAME := TextExtractorDemo
DEMO_PROJECT := Examples/$(DEMO_NAME)/$(DEMO_NAME).xcodeproj
DEMO_SCHEME := $(DEMO_NAME)
DEMO_DERIVED_DATA ?= $(HOME)/Developer/tmp/$(DEMO_NAME)DerivedData
DEMO_APP := $(DEMO_DERIVED_DATA)/Build/Products/Debug/$(DEMO_NAME).app

.PHONY: demo build open clean

demo: build open

build:
	xcodebuild \
		-scheme $(DEMO_SCHEME) \
		-project $(DEMO_PROJECT) \
		-destination 'platform=macOS' \
		-derivedDataPath $(DEMO_DERIVED_DATA) \
		CODE_SIGNING_ALLOWED=NO \
		build

open:
	@test -d "$(DEMO_APP)" || { \
		echo "Demo app not found. Run 'make demo-build' first."; \
		exit 1; \
	}
	@if pgrep -x "$(DEMO_SCHEME)" >/dev/null; then \
		pkill -x "$(DEMO_SCHEME)"; \
		attempt=0; \
		while pgrep -x "$(DEMO_SCHEME)" >/dev/null && [ $$attempt -lt 50 ]; do \
			sleep 0.1; \
			attempt=$$((attempt + 1)); \
		done; \
	fi
	open -n "$(DEMO_APP)"

clean:
	rm -rf "$(DEMO_DERIVED_DATA)"
