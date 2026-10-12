APP_NAME = pastep
BUNDLE   = $(APP_NAME).app
BINARY   = .build/release/$(APP_NAME)

.PHONY: build app run test clean

build:
	swift build -c release

app: build
	rm -rf $(BUNDLE)
	mkdir -p $(BUNDLE)/Contents/MacOS
	cp $(BINARY) $(BUNDLE)/Contents/MacOS/$(APP_NAME)
	cp Info.plist $(BUNDLE)/Contents/Info.plist
	@echo "✓ $(BUNDLE) を作成しました"

run: app
	open $(BUNDLE)

test:
	swift test

clean:
	rm -rf .build $(BUNDLE)
