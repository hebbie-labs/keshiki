# Keshiki

**living wallpapers for your Mac**

Keshiki (景色, "scenery") puts a living pixel-art scene behind your desktop
icons. The first scene is a koi pond: the koi swim on their own, come over when
you click the water and learn when you usually feed them. More scenes will follow.

## Install

1. Download `Keshiki-<version>.dmg` from the
   [latest release](https://github.com/hebbie-labs/keshiki/releases/latest).
2. Open it and drag **Keshiki** into **Applications**.
3. The app is not notarized, so macOS blocks the first launch. Either open
   *System Settings → Privacy & Security* and click **Open Anyway**, or run:

   ```sh
   xattr -dr com.apple.quarantine /Applications/Keshiki.app
   ```

Requires macOS 14 or later on Apple Silicon. Keshiki lives in the menu bar
(鯉); add it to *Login Items* to start it automatically. Coming from
*Wallpapers* 1.x? Keshiki picks up your settings and what the koi learned on
its first launch.

## Everywhere

- **Every display**, one scene for all of them.
- **Dawn to night on your clock** (or synced with dark mode), fireflies after
  dark, rain on demand.
- **Lock screen:** a still of the scene becomes the desktop picture, which the
  lock screen shows; it follows the time of day and your own picture comes back
  when you quit. *Install Screensaver…* adds the animated scene as a system
  screensaver too.
- **Light on memory:** drawn natively into a small pixel buffer, about 40 MB
  for three displays. Scenes hidden behind windows aren't drawn, and it can
  rest on battery.

## Koi Pond

- **Eight koi with a life of their own.** Each has a favourite: herding the
  tiny fish, grazing duckweed, lotus shade, the frog, the ball or the goose.
- **A living pond.** Clear water with a wobbling net of sunlight on the floor,
  shafts of light, water plants along the shallow edges, deep shadows under
  the lily pads, and schools of Japanese pond fish (hime-medaka, tanago
  bitterlings, oikawa and motsugo) that swim in bursts and glides.
- **They learn your routine.** Feed them at the same spot around the same time
  on two different days and they'll be waiting there.
- **A good-morning greeting.** The first time you see the pond each day they
  gather at your spot to say hello.
- **Click the water** and they swim over. **⌥-click** drops food.
- **Calm or playful** mood, a *Deep Clear* water theme, and visitors: invite
  the goose or drop a temari ball.

## Development

```sh
make run       # build build/Keshiki.app (with the screensaver inside) and launch it
make dmg       # build build/Keshiki-<version>.dmg
make test      # build and run the checks
```

The version comes from `CFBundleShortVersionString` in `App/Info.plist`.

## Structure

- `Core/` — shared by every scene: `LivingScene` (what a scene must do),
  `PixelBuffer` (drawn every frame, scaled up with nearest-neighbour),
  `Atmosphere` (time of day, rain, fireflies) and `KeshikiSettings`.
- `Scenes/` — `SceneKind` lists every scene; each has its own folder.
  - `KoiPond/` — `KoiPondScene` owns a `PondWorld` (`Koi`, `FishSchool`,
    `Frog`, `Goose`, `Ball`, `LilyPad`, duckweed, food, ripples), the painted
    `PondFloor`, `Caustics`, the learning in `KoiMemory` and `KoiPondSettings`.
- `App/` — the menu bar app (AppKit, no Xcode project needed).
  - `KeshikiController` wires everything and runs the 30 fps frame timer.
  - `SceneDisplays` / `SceneWindow` / `SceneView` keep one borderless window
    per display at desktop level.
  - `SceneControls` is what a scene adds to the app: `KoiPondControls` holds
    the koi menu section, feeding memory and the morning greeting.
  - `DesktopHitTest` decides whether a click landed on the bare desktop; the
    desktop belongs to Finder, so clicks are watched globally and forwarded.
  - `LockScreenWallpaper` swaps the desktop pictures for scene stills and back.
  - `StatusMenu` / `MenuEntry` build the menu; `SettingsStore` persists
    settings and migrates from Wallpapers 1.x.
- `Saver/` — `KeshikiSaverView`, the scenes as a `.saver` bundle.
- `Tests/` — runnable checks (learning, time of day, settings migration, drawing).
- `Assets/` — app icon.

To add a scene: a folder under `Scenes/` with a class conforming to
`LivingScene`, a case in `SceneKind`, and — if it has its own options — a
`SceneControls` in `App/`.

Inspired by [Nagomi](https://nagomi.m4yank.com/). All code and pixel art
here is original and drawn procedurally.
