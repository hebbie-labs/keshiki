import AppKit

/// A menu item that runs a closure and shows a checkmark while `isOn` returns true.
final class MenuEntry: NSMenuItem {
    private let handler: () -> Void
    private let isOn: () -> Bool

    init(_ title: String, isOn: @escaping () -> Bool = { false }, handler: @escaping () -> Void) {
        self.handler = handler
        self.isOn = isOn
        super.init(title: title, action: #selector(run), keyEquivalent: "")
        target = self
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("MenuEntry is created in code only")
    }

    func refreshCheckmark() {
        state = isOn() ? .on : .off
    }

    @objc private func run() {
        handler()
    }
}
