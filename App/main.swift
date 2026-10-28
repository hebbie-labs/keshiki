import AppKit

// Before anything reads settings: bring over what the app saved back when it was called Wallpapers.
SettingsStore.migrateFromWallpapersIfNeeded()

let app = NSApplication.shared
let controller = KeshikiController()
app.delegate = controller
app.setActivationPolicy(.accessory)
app.run()
