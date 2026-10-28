import AppKit

/// The koi pond's own menu section, plus the learning: feeding routine and the morning greeting.
final class KoiPondControls: SceneControls {
    private var options = SettingsStore.load(SettingsStore.koiPondKey, default: KoiPondSettings()) {
        didSet {
            SettingsStore.save(options, as: SettingsStore.koiPondKey)
            ponds.forEach { $0.options = options }
        }
    }
    private var memory = SettingsStore.load(SettingsStore.koiMemoryKey, default: KoiMemory()) {
        didSet { SettingsStore.save(memory, as: SettingsStore.koiMemoryKey) }
    }
    private let scenes: () -> [LivingScene]

    private static let greetingSeconds: TimeInterval = 12

    init(scenes: @escaping () -> [LivingScene]) {
        self.scenes = scenes
    }

    private var ponds: [KoiPondScene] {
        scenes().compactMap { $0 as? KoiPondScene }
    }

    func configure(_ scene: LivingScene) {
        guard let pond = scene as? KoiPondScene else { return }
        pond.options = options
        pond.onFeed = { [weak self] spot in self?.memory.recordFeeding(at: spot, on: Date()) }
    }

    func menuItems() -> [NSMenuItem] {
        let binding = MenuBinding(get: { [unowned self] in options }, set: { [unowned self] in options = $0 })
        return [
            submenu("Koi Mood", [binding.choice("Calm", \.mood, "calm"), binding.choice("Playful", \.mood, "playful")]),
            submenu("Water", [binding.choice("Koi Pond", \.water, "pond"), binding.choice("Deep Clear", \.water, "deep-clear")]),
            submenu("Visitors", [
                MenuEntry("Invite the Goose") { [unowned self] in invite(.goose) },
                MenuEntry("Drop a Temari Ball") { [unowned self] in invite(.ball) },
                .separator(),
                MenuEntry("Clear Visitors") { [unowned self] in invite(.clear) },
            ]),
            binding.toggle("Call Fish on Click", \.callOnClick),
            binding.toggle("Feed Koi with ⌥-Click", \.feedOnAlt),
        ]
    }

    /// The koi wait at your usual feeding spot, and greet you the first time you see them each day.
    func checkIn(windows: [SceneWindow], isResting: Bool) {
        let now = Date()
        let usualSpot = memory.usualSpot(at: now)
        ponds.forEach { pond in pond.world.usualSpot = usualSpot.map { pond.pondPoint(fromNormalized: $0) } }
        guard !isResting, memory.claimDailyGreeting(on: now) else { return }
        let spot = usualSpot ?? memory.lastFeedingSpot ?? Point(x: 0.5, y: 0.5)
        for window in windows {
            guard let pond = window.scene as? KoiPondScene else { continue }
            pond.world.gather(at: pond.pondPoint(fromNormalized: spot))
            window.showCaption("good morning", at: spot)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.greetingSeconds) { [weak self] in
            self?.ponds.forEach { $0.world.scatter() }
        }
    }

    private func invite(_ visitor: Visitor) {
        ponds.forEach { $0.world.invite(visitor) }
    }
}
