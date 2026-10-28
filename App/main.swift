import AppKit

let app = NSApplication.shared
let controller = PondController()
app.delegate = controller
app.setActivationPolicy(.accessory)
app.run()
