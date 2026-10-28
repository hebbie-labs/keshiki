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
- **A living pond.** Clear water with a wobbling net of sunlight on the floor,
  shafts of light, water plants along the shallow edges, deep shadows under
  the lily pads, and schools of ember, neon and citrus fish.
- **They learn your routine.** Feed them at the same spot around the same time
  on two different days and they'll be waiting there.
- **A good-morning greeting.** The first time you see the pond each day they
  gather at your spot to say hello.
- **Click the water** and they swim over. **⌥-click** drops food.
- **Dawn to night on your clock** (or synced with dark mode), fireflies after
  dark, rain on demand, and a *Deep Clear* water theme.
- **Visitors:** invite the goose or drop a temari ball.
- **Lock screen:** a still of the pond becomes the desktop picture, which the
  lock screen shows; it follows the time of day and your own picture comes back
  when you quit. *Install Screensaver…* adds the animated pond as a system
  screensaver too.
- **Light on memory:** drawn natively into a small pixel buffer, about 40 MB
  for three displays. Ponds hidden behind windows aren't drawn at all, and it
  can rest on battery.

## Development

```sh
make run       # build build/Wallpapers.app (with the screensaver inside) and launch it
make dmg       # build build/Wallpapers-<version>.dmg
make test      # build and run the engine checks
```

The version comes from `CFBundleShortVersionString` in `App/Info.plist`.

## Structure

- `Engine/` — the pond, shared by the app and the screensaver. A 960 px wide
  `PixelBuffer` is drawn every frame and scaled up with nearest-neighbour.
  - `PondScene` owns one pond: its `World` and the painted floor.
  - `World` holds the residents (`Koi`, `FishSchool`, `Frog`, `Goose`, `Ball`,
    `LilyPad`, duckweed, food, ripples) and the draw order.
  - `PondFloor` paints the still parts once (floor, plants, water depth,
    light rays); `Caustics` precomputes a seamless looping light net.
  - `PondMemory` is the learning; `Sky` the time of day and fireflies.
- `App/` — the menu bar app (AppKit, no Xcode project needed).
  - `PondController` wires everything and runs the 30 fps frame timer.
  - `PondDisplays` / `PondWindow` / `PondView` keep one borderless window per
    display at desktop level.
  - `DesktopHitTest` decides whether a click landed on the bare desktop; the
    desktop belongs to Finder, so clicks are watched globally and forwarded.
  - `LockScreenWallpaper` swaps the desktop pictures for pond stills and back.
  - `StatusMenu` / `MenuEntry` build the menu from the settings.
- `Saver/` — `PondSaverView`, the engine as a `.saver` bundle.
- `Tests/` — engine checks (learning, time of day, rendering).
- `Assets/` — app icon.

Inspired by [Nagomi](https://nagomi.m4yank.com/). All code and pixel art
here is original and drawn procedurally.
