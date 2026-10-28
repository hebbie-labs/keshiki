# Wallpapers

**a living koi pond for your desktop**

A pixel-art koi pond that runs as a live wallpaper on macOS. The koi swim
behind your desktop icons, come over when you click the water and learn when
you usually feed them.

## Install

1. Download `Wallpapers-<version>.dmg` from the
   [latest release](https://github.com/hebbie-labs/wallpapers/releases/latest).
2. Open it and drag **Wallpapers** into **Applications**.
3. The app is not notarized, so macOS blocks the first launch. Either open
   *System Settings → Privacy & Security* and click **Open Anyway**, or run:

   ```sh
   xattr -dr com.apple.quarantine /Applications/Wallpapers.app
   ```

Requires macOS 14 or later on Apple Silicon. Wallpapers lives in the menu bar
(鯉); add it to *Login Items* to start it automatically.

## What's in the pond

- **Eight koi with a life of their own.** Each has a favourite: herding the
  tiny fish, grazing duckweed, lotus shade, the frog, the ball or the goose.
- **They learn your routine.** Feed them at the same spot around the same time
  on two different days and they'll be waiting there.
- **A good-morning greeting.** The first time you see the pond each day they
  gather at your spot to say hello.
- **Click the water** and they swim over. **⌥-click** drops food.
- **Dawn to night on your clock** (or synced with dark mode), fireflies after
  dark, rain on demand, and a *Deep Clear* water theme.
- **Visitors:** invite the goose or drop a temari ball.
- **Calm or playful** mood.
- **Screensaver mode**, one pond per display, rests on battery if you like.
  Pauses by itself when windows cover it. Works offline, no tracking.

## Development

```sh
make run       # build build/Wallpapers.app and launch it
make dmg       # build build/Wallpapers-<version>.dmg
make test      # unit tests (Node 20+)
make preview   # serve the pond at http://localhost:8000/?theme=night&rain=1
```

The version comes from `CFBundleShortVersionString` in `App/Info.plist`.

## Structure

- `App/` — the macOS host in Swift (AppKit + WebKit), no Xcode project needed.
  - `PondController` wires everything together.
  - `PondDisplays` / `PondWindow` keep one borderless window per display at
    desktop level.
  - `DesktopHitTest` decides whether a click landed on the bare desktop;
    the desktop belongs to Finder, so clicks are watched globally and
    forwarded to the pond.
  - `StatusMenu` / `MenuEntry` build the menu bar menu from the settings.
  - `PondSchemeHandler` serves the page over `pond://`, because WebKit won't
    load ES modules from `file://`.
  - `PondSettings` and `PondMemory` persist settings and what the koi learned.
- `Pond/` — the pond itself: a 960 px wide canvas scaled up pixelated, in plain
  ES modules (`koi.js`, `school.js`, `frog.js`, `goose.js`, `sky.js`, …).
  `main.js` is the entry point and exposes `window.pond` to the app.
- `tests/` — Node tests for the learning (`memory.js`) and the time of day
  (`sky.js`).
- `Assets/` — app icon.

Inspired by [Nagomi](https://nagomi.m4yank.com/). All code and pixel art
here is original and drawn procedurally.
