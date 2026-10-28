APP_NAME := Wallpapers
APP      := build/$(APP_NAME).app
SAVER    := build/$(APP_NAME).saver
VERSION  := $(shell /usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' App/Info.plist)
DMG      := build/$(APP_NAME)-$(VERSION).dmg
ENGINE   := $(wildcard Engine/*.swift)
SWIFTC   := swiftc -O -swift-version 5 -target arm64-apple-macos14.0

.PHONY: app saver dmg run test clean

app: saver
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	$(SWIFTC) $(ENGINE) $(wildcard App/*.swift) -o $(APP)/Contents/MacOS/$(APP_NAME)
	cp App/Info.plist $(APP)/Contents/Info.plist
	cp Assets/AppIcon.icns $(APP)/Contents/Resources/
	cp -R $(SAVER) $(APP)/Contents/Resources/
	codesign --force --deep --sign - $(APP)

# The same engine as a system screensaver (a loadable bundle).
saver:
	rm -rf $(SAVER)
	mkdir -p $(SAVER)/Contents/MacOS $(SAVER)/Contents/Resources
	$(SWIFTC) -module-name PondSaver -emit-library -Xlinker -bundle -Xlinker -undefined -Xlinker dynamic_lookup \
		$(ENGINE) $(wildcard Saver/*.swift) -o $(SAVER)/Contents/MacOS/PondSaver
	cp Saver/Info.plist $(SAVER)/Contents/Info.plist
	cp Assets/AppIcon.icns $(SAVER)/Contents/Resources/thumbnail.icns
	codesign --force --sign - $(SAVER)

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
	mkdir -p build
	$(SWIFTC) $(ENGINE) $(wildcard Tests/*.swift) -o build/engine-checks
	build/engine-checks

clean:
	rm -rf build
