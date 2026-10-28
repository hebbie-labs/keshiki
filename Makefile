APP_NAME := Wallpapers
APP      := build/$(APP_NAME).app
VERSION  := $(shell /usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' App/Info.plist)
DMG      := build/$(APP_NAME)-$(VERSION).dmg
SOURCES  := $(wildcard App/*.swift)

.PHONY: app dmg run test preview clean

app: $(SOURCES) App/Info.plist $(shell find Pond Assets -type f)
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	swiftc -O -swift-version 5 -target arm64-apple-macos14.0 $(SOURCES) -o $(APP)/Contents/MacOS/$(APP_NAME)
	cp App/Info.plist $(APP)/Contents/Info.plist
	cp -R Pond $(APP)/Contents/Resources/Pond
	cp Assets/AppIcon.icns $(APP)/Contents/Resources/
	codesign --force --sign - $(APP)

dmg: app
	rm -rf build/dmg $(DMG)
	mkdir -p build/dmg
	cp -R $(APP) build/dmg/
	ln -s /Applications build/dmg/Applications
	hdiutil create -volname "$(APP_NAME)" -srcfolder build/dmg -fs HFS+ -format UDZO $(DMG)
	rm -rf build/dmg

run: app
	-pkill -x $(APP_NAME)
	open $(APP)

test:
	node --test tests/

# Open the pond in a browser: http://localhost:8000/?theme=night&rain=1
preview:
	python3 -m http.server 8000 --directory Pond

clean:
	rm -rf build
