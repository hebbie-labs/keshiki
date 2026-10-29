APP_NAME := Keshiki
APP      := build/$(APP_NAME).app
SAVER    := build/$(APP_NAME).saver
WALLPAPER := build/$(APP_NAME)Wallpaper.appex
VERSION  := $(shell /usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' App/Info.plist)
DMG      := build/$(APP_NAME)-$(VERSION).dmg
ENGINE   := $(wildcard Core/*.swift Scenes/*.swift Scenes/*/*.swift)
SWIFTC   := swiftc -O -enforce-exclusivity=unchecked -swift-version 5 -target arm64-apple-macos14.0

.PHONY: app saver wallpaper dmg run test clean

app: saver wallpaper
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources $(APP)/Contents/Extensions
	$(SWIFTC) $(ENGINE) $(wildcard App/*.swift) -o $(APP)/Contents/MacOS/$(APP_NAME)
	cp App/Info.plist $(APP)/Contents/Info.plist
	cp Assets/AppIcon.icns $(APP)/Contents/Resources/
	cp -R $(SAVER) $(APP)/Contents/Resources/
	cp -R $(WALLPAPER) $(APP)/Contents/Extensions/
	codesign --force --sign - $(APP)

# The same scenes as a system screensaver (a loadable bundle).
saver:
	rm -rf $(SAVER)
	mkdir -p $(SAVER)/Contents/MacOS $(SAVER)/Contents/Resources
	$(SWIFTC) -module-name KeshikiSaver -emit-library -Xlinker -bundle -Xlinker -undefined -Xlinker dynamic_lookup \
		$(ENGINE) $(wildcard Saver/*.swift) -o $(SAVER)/Contents/MacOS/KeshikiSaver
	cp Saver/Info.plist $(SAVER)/Contents/Info.plist
	cp Assets/AppIcon.icns $(SAVER)/Contents/Resources/thumbnail.icns
	codesign --force --sign - $(SAVER)

# The scenes as a system wallpaper for the lock screen (macOS 26+), through the private WallpaperExtensionKit.
wallpaper:
	rm -rf $(WALLPAPER)
	mkdir -p $(WALLPAPER)/Contents/MacOS
	swiftc -O -enforce-exclusivity=unchecked -swift-version 5 -target arm64-apple-macos26.0 -parse-as-library \
		-module-name KeshikiWallpaper -import-objc-header Wallpaper/Bridge.h -Xlinker -e -Xlinker _NSExtensionMain \
		$(ENGINE) $(wildcard Wallpaper/*.swift) -o $(WALLPAPER)/Contents/MacOS/KeshikiWallpaper
	cp Wallpaper/Info.plist $(WALLPAPER)/Contents/Info.plist
	codesign --force --sign - --entitlements Wallpaper/Wallpaper.entitlements $(WALLPAPER)

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
