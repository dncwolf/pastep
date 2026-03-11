APP_NAME = pastep
BUNDLE   = $(APP_NAME).app
BINARY   = .build/arm64-apple-macosx/release/$(APP_NAME)

.PHONY: build app run clean

build:
	swift build -c release --arch arm64

app: build
	rm -rf $(BUNDLE)
	mkdir -p $(BUNDLE)/Contents/MacOS
	cp $(BINARY) $(BUNDLE)/Contents/MacOS/$(APP_NAME)
	cp Info.plist $(BUNDLE)/Contents/Info.plist
	codesign --force --deep --sign "pastep-codesign" $(BUNDLE) 2>/dev/null || codesign --force --deep --sign - $(BUNDLE)
	@echo "✓ $(BUNDLE) を作成しました"

run: app
	open $(BUNDLE)

clean:
	rm -rf .build $(BUNDLE)
