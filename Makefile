APP      = TouchBar Temp
BINARY   = touchbar-temp
SOURCES  = $(wildcard Sources/$(BINARY)/*.swift)
BUNDLE   = $(APP).app

.PHONY: build app run clean

build: $(SOURCES)
	swiftc -O \
		-target arm64-apple-macosx12.0 \
		$(SOURCES) \
		-o "$(BINARY)" \
		-framework AppKit \
		-framework IOKit \
		-framework Foundation

app: build
	@mkdir -p "$(BUNDLE)/Contents/MacOS"
	@cp "$(BINARY)" "$(BUNDLE)/Contents/MacOS/"
	@cp Resources/Info.plist "$(BUNDLE)/Contents/"
	@codesign --force --sign - "$(BUNDLE)"
	@echo "✓  Built: $(BUNDLE)"

run: app
	@open "$(BUNDLE)"

clean:
	@rm -rf "$(BINARY)" "$(BUNDLE)"
	@echo "✓  Clean"
