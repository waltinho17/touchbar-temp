APP      = TouchBar Temp
BINARY   = touchbar-temp
VERSION  = 1.0.0
SOURCES  = $(wildcard Sources/$(BINARY)/*.swift)
BUNDLE   = $(APP).app
PKG      = TouchBar-Temp-v$(VERSION).pkg

.PHONY: build app pkg run clean

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

pkg: app
	@rm -rf /tmp/tbt-root /tmp/tbt-scripts
	@mkdir -p /tmp/tbt-root/Applications /tmp/tbt-scripts
	@cp -r "$(BUNDLE)" /tmp/tbt-root/Applications/
	@printf '#!/bin/bash\nxattr -cr "/Applications/TouchBar Temp.app"\nexit 0\n' \
		> /tmp/tbt-scripts/postinstall
	@chmod +x /tmp/tbt-scripts/postinstall
	@pkgbuild \
		--root /tmp/tbt-root \
		--scripts /tmp/tbt-scripts \
		--identifier com.touchbar-temp \
		--version $(VERSION) \
		--install-location / \
		"$(PKG)"
	@rm -rf /tmp/tbt-root /tmp/tbt-scripts
	@echo "✓  Built: $(PKG)"

run: app
	@xattr -cr "$(BUNDLE)"
	@open "$(BUNDLE)"

clean:
	@rm -rf "$(BINARY)" "$(BUNDLE)" "$(PKG)" TouchBar-Temp-*.zip
	@echo "✓  Clean"
