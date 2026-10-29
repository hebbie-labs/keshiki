# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and test

No Xcode project and no SwiftPM: the `Makefile` calls `swiftc` directly on file globs (Swift 5 mode, `arm64-apple-macos14.0`, ad-hoc codesigned).

```sh
make run    # build build/Keshiki.app (screensaver bundled inside) and relaunch it
make app    # build only
make saver  # build only build/Keshiki.saver
make wallpaper  # build only build/KeshikiWallpaper.appex (macOS 26+, linked with -e _NSExtensionMain)
make dmg    # build/Keshiki-<version>.dmg; version = CFBundleShortVersionString in App/Info.plist
make test   # compile Core + Scenes + Tests into build/engine-checks and run it
```

- Tests are a plain executable (`Tests/main.swift`), not XCTest: `check(condition, "description")` prints ✔/✘. There is no way to run a single check; add or edit `check` calls and run `make test`. GPU checks need a Metal device.
- Metal shaders (`Core/Shaders.swift`, `Core/StageShaders.swift`) are Swift string literals compiled at runtime with `makeLibrary(source:)`. Shader errors only show up at runtime (renderer init returns nil), not at build time.

## Architecture

Four targets share one engine. `ENGINE` = `Core/*.swift` + `Scenes/**/*.swift`, compiled into:
- the app with `App/*.swift` (AppKit menu bar app, entry point `App/main.swift`),
- the screensaver with `Saver/*.swift` (module `KeshikiSaver`, loadable bundle),
- the wallpaper extension with `Wallpaper/*.swift` (ExtensionKit appex in `Contents/Extensions`, sandboxed; speaks the private WallpaperAgent XPC protocol declared in `Wallpaper/Bridge.h`),
- the test binary with `Tests/*.swift`.

So anything in `Core/` or `Scenes/` must not depend on `App/`. App-only scene UI goes into a `SceneControls` in `App/` (e.g. `KoiPondControls`).

Frame flow (30 fps timer in `KeshikiController`, one borderless desktop-level window per display):
1. A `LivingScene` (`Core/LivingScene.swift`) advances its simulation and draws into a `Canvas` in design units (960 wide), recorded as a `DrawList` of rects/discs.
2. Static layers (backdrop, overlay) are painted once on the CPU as `PixelBuffer`s and handed over via `takeNewBackdrop()` / `takeNewOverlay()`; the scene drops its copy after upload.
3. `SceneRenderer` draws the `DrawList` as instanced quads at `pixelScale` (1.5 → 1440 px) into pixel-art layers; the scene's `WaterSurface` drives a height-field water simulation in a compute shader.
4. `WaterStage` composes it in 3D (floor basin, swimming layer under the surface, waves carrying the floating layer, sky reflection).

Displays with any app window on them (`WindowWatcher`) pause: no simulation, no drawing. Clicks on the desktop belong to Finder, so they're watched globally and filtered by `DesktopHitTest` before reaching `touch(at:withOption:)` (spot in 0...1, origin top-left).

Settings are JSON-encoded `Codable` structs in `UserDefaults` (`App/SettingsStore.swift`): general `KeshikiSettings` plus per-scene settings and `KoiMemory`. On first launch it migrates from the old *Wallpapers 1.x* bundle; decoding must stay compatible with those old keys (covered by tests). The sandboxed screensaver and wallpaper extension read them through `SharedSettings`: the extension reads the app's preferences domain (read-only sandbox exception), the screensaver a copy the app writes into its container.

Adding a scene: a folder under `Scenes/` with a class conforming to `LivingScene`, a case in `SceneKind`, and optionally a `SceneControls` in `App/`.

## Conventions

- All code and pixel art is original and procedural; no image assets besides `Assets/AppIcon.icns`.
