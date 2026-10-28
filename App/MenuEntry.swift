import AppKit

/// A menu item that runs a closure.
final class MenuEntry: NSMenuItem {
    private let handler: () -> Void

    init(_ title: String, isOn: Bool = false, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: "")
        target = self
        state = isOn ? .on : .off
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("MenuEntry is created in code only")
    }

    @objc private func run() {
        handler()
    }
}

/// Builds checkable menu entries for one settings value, read and written through closures.
struct MenuBinding<Settings> {
    let get: () -> Settings
    let set: (Settings) -> Void

    func toggle(_ title: String, _ keyPath: WritableKeyPath<Settings, Bool>) -> MenuEntry {
        MenuEntry(title, isOn: get()[keyPath: keyPath]) {
            var settings = get()
            settings[keyPath: keyPath].toggle()
            set(settings)
        }
    }

    func choice<Value: Equatable>(_ title: String, _ keyPath: WritableKeyPath<Settings, Value>, _ value: Value) -> MenuEntry {
        MenuEntry(title, isOn: get()[keyPath: keyPath] == value) {
            var settings = get()
            settings[keyPath: keyPath] = value
            set(settings)
        }
    }
}

func submenu(_ title: String, _ items: [NSMenuItem]) -> NSMenuItem {
    let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
    item.submenu = NSMenu()
    item.submenu?.items = items
    return item
}
