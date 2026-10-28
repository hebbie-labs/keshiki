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
- **Only where you can see it:** a display's scene plays while its desktop is
  free. As soon as any app window lies on that display (focused or not), or the
  desktop is covered, it rests: the last frame stays, and nothing is simulated
  or drawn there. It can rest on battery too.
- **Light on the machine:** drawn on the GPU with Metal: the pixel art at
  1440 px wide, scaled up with crisp pixels, and the water at the display's
  full resolution. Measured on an Apple Silicon Mac (M-series, 30 fps, GPU time
  per frame): about 2.5 % CPU and 3.3 % GPU for a 3024×1964 Retina display,
  2.1 % GPU for a 1920×1200 one.

## Koi Pond

- **Eight koi with a life of their own.** Each has a favourite: herding the
  tiny fish, grazing duckweed, lotus shade, the frog, the ball or the goose.
- **Real water.** Waves spread, overlap and bounce off the edges and the lily
  pads, bend the view of the floor, focus sunlight into a moving net of light
  and catch the sun. Clicks, food, rain, the frog and the goose all make waves.
- **A living pond.** Clear water over a sunlit floor,
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

- `Core/` — shared by every scene.
  - `LivingScene` is what a scene must do; scenes draw into a `Canvas` in
    design units (960 wide) and render at `pixelScale` (1.5 → 1440 px).
  - `DrawList` records each frame as rectangles and discs; `SceneRenderer`
    draws them on the GPU as instanced quads (`Shaders`) over the scene's
    painted backdrop, in two layers below and above a static overlay (stored
    as a palette texture). A scene's `WaterSurface` says where the water can't
    move and where it was disturbed; the renderer simulates it as a height
    field in a compute shader and puts the layers together at the display's
    resolution, with the water bending, lighting and reflecting the layer
    below. All displays share one GPU submission per frame.
  - `PixelBuffer` paints the static layers once on the CPU; their CPU copies
    are dropped after upload.
  - `Atmosphere` (time of day, rain, fireflies) and `KeshikiSettings`.
- `Scenes/` — `SceneKind` lists every scene; each has its own folder.
  - `KoiPond/` — `KoiPondScene` owns a `PondWorld` (`Koi`, `FishSchool`,
    `Frog`, `Goose`, `Ball`, `LilyPad`, duckweed, food, and the ripples they
    make in the water), the painted
    `PondFloor` (backdrop) and lily pads (overlay), the learning in `KoiMemory`
    and `KoiPondSettings`.
- `App/` — the menu bar app (AppKit, no Xcode project needed).
  - `KeshikiController` wires everything and runs the 30 fps frame timer.
  - `WindowWatcher` knows which displays have app windows on them.
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
- `Tests/` — runnable checks (learning, time of day, settings migration,
  drawing, and that the GPU draws pixel for pixel like the CPU).
- `Assets/` — app icon.

To add a scene: a folder under `Scenes/` with a class conforming to
`LivingScene`, a case in `SceneKind`, and — if it has its own options — a
`SceneControls` in `App/`.

Inspired by [Nagomi](https://nagomi.m4yank.com/). All code and pixel art
here is original and drawn procedurally.
