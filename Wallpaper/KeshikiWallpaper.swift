import AppKit
import ExtensionFoundation
import Security

/// Keshiki as a system wallpaper (macOS 26+), so the scene also plays on the lock screen and as the screensaver.
/// macOS has no public API for this: the extension speaks the private protocol of the WallpaperAgent, which hosts
/// a layer tree we draw into. Pick "Koi Pond" under System Settings → Wallpaper.
@main
final class KeshikiWallpaper: NSObject, AppExtension {
    override required init() {
        super.init()
        // The agent's XPC classes live in this framework; without them nothing decodes.
        dlopen("/System/Library/PrivateFrameworks/WallpaperExtensionKit.framework/WallpaperExtensionKit", RTLD_LAZY)
        DispatchQueue.main.async { Surfaces.shared.start() }
    }

    var configuration: some AppExtensionConfiguration { AgentConnection() }
}

struct AgentConnection: AppExtensionConfiguration {
    func accept(connection: NSXPCConnection) -> Bool {
        guard Self.isFromApple(connection) else { return false }
        let exported = NSXPCInterface(with: WallpaperExtensionXPCProtocol.self)
        // The agent's private argument types, found at runtime, plus the plain ones they carry.
        let names = ["WallpaperIDXPC", "WallpaperCreationRequestXPC", "WallpaperUpdateRequestXPC", "WallpaperRemoteContextXPC",
                     "WallpaperSnapshotXPC", "WallpaperContentTypeSetXPC", "WallpaperChoiceIDXPC", "WallpaperChoiceIDsXPC",
                     "WallpaperExtensionChoiceRequestXPC", "WallpaperChoiceRequestAdditionResultXPC", "WallpaperDebugRequestXPC",
                     "WallpaperDebugResponseXPC", "WallpaperMigrationVersionXPC", "WallpaperSettingsViewModelsXPC", "AuditTokenXPC"]
        let classes = NSMutableSet(array: [NSString.self, NSNumber.self, NSData.self, NSArray.self, NSDictionary.self, NSURL.self, NSError.self])
        names.compactMap { objc_getClass($0) }.forEach { classes.add($0) }
        let allowed = classes as! Set<AnyHashable>
        let arguments: [(Selector, Int, Bool)] = [
            (#selector(AgentRequests.acquire(withId:request:reply:)), 0, false),
            (#selector(AgentRequests.acquire(withId:request:reply:)), 1, false),
            (#selector(AgentRequests.acquire(withId:request:reply:)), 0, true),
            (#selector(AgentRequests.update(withId:request:reply:)), 0, false),
            (#selector(AgentRequests.update(withId:request:reply:)), 1, false),
            (#selector(AgentRequests.invalidate(withId:reply:)), 0, false),
            (#selector(AgentRequests.snapshot(withId:reply:)), 0, false),
            (#selector(AgentRequests.snapshot(withId:reply:)), 0, true),
            (#selector(AgentRequests.provideSettingsViewModels(withContentTypes:reply:)), 0, false),
            (#selector(AgentRequests.provideSettingsViewModels(withContentTypes:reply:)), 0, true),
            (#selector(AgentRequests.addChoiceRequest(withChoiceRequest:onBehalfOfProcess:reply:)), 0, false),
            (#selector(AgentRequests.addChoiceRequest(withChoiceRequest:onBehalfOfProcess:reply:)), 1, false),
            (#selector(AgentRequests.addChoiceRequest(withChoiceRequest:onBehalfOfProcess:reply:)), 0, true),
            (#selector(AgentRequests.removeChoiceRequest(withChoiceRequest:reply:)), 0, false),
            (#selector(AgentRequests.selectedChoicesDidChange(for:reply:)), 0, false),
            (#selector(AgentRequests.invokeContextMenuAction(withMenuItemID:groupItemID:reply:)), 0, false),
            (#selector(AgentRequests.invokeContextMenuAction(withMenuItemID:groupItemID:reply:)), 1, false),
            (#selector(AgentRequests.isChoiceDownloaded(with:reply:)), 0, false),
            (#selector(AgentRequests.download(withChoiceID:reply:)), 0, false),
            (#selector(AgentRequests.pauseDownload(for:reply:)), 0, false),
            (#selector(AgentRequests.cancelDownload(for:reply:)), 0, false),
            (#selector(AgentRequests.resumeDownload(for:reply:)), 0, false),
            (#selector(AgentRequests.removeDownload(for:reply:)), 0, false),
            (#selector(AgentRequests.migrateSelectedChoice(for:reply:)), 0, false),
            (#selector(AgentRequests.migrateSelectedChoice(for:reply:)), 0, true),
            (#selector(AgentRequests.migrate(from:to:reply:)), 0, false),
            (#selector(AgentRequests.migrate(from:to:reply:)), 1, false),
            (#selector(AgentRequests.skipShuffledContent(withId:reply:)), 0, false),
            (#selector(AgentRequests.canSkipShuffledContent(withId:reply:)), 0, false),
            (#selector(AgentRequests.handleDebugRequest(for:reply:)), 0, false),
            (#selector(AgentRequests.handleDebugRequest(for:reply:)), 0, true),
            (#selector(AgentRequests.handleNotification(withNamed:reply:)), 0, false),
        ]
        for (selector, index, ofReply) in arguments {
            exported.setClasses(allowed, for: selector, argumentIndex: index, ofReply: ofReply)
        }
        connection.exportedInterface = exported
        connection.remoteObjectInterface = NSXPCInterface(with: WallpaperExtensionProxyXPCProtocol.self)
        connection.exportedObject = AgentRequests()
        connection.resume()
        return true
    }

    /// Only Apple's own processes (the WallpaperAgent and System Settings) may drive the extension.
    /// If the caller can't be identified at all, it's let in, so an OS change doesn't break the wallpaper.
    private static func isFromApple(_ connection: NSXPCConnection) -> Bool {
        guard connection.responds(to: NSSelectorFromString("auditToken")) else { return true }
        var token = connection.auditToken
        var code: SecCode?, requirement: SecRequirement?
        guard SecCodeCopyGuestWithAttributes(nil, [kSecGuestAttributeAudit: Data(bytes: &token, count: MemoryLayout.size(ofValue: token))] as CFDictionary,
                                             [], &code) == errSecSuccess, let code,
              SecRequirementCreateWithString("anchor apple" as CFString, [], &requirement) == errSecSuccess else { return true }
        return SecCodeCheckValidity(code, [], requirement) == errSecSuccess
    }
}

/// The agent's calls. Its request objects are private Swift types, so their fields are read by reflection.
final class AgentRequests: NSObject, WallpaperExtensionXPCProtocol {
    func acquire(withId id: Any?, request: Any?, reply: @escaping (Any?, Error?) -> Void) {
        let size = request.flatMap { field("size", in: $0) as? CGSize } ?? CGSize(width: 1440, height: 900)
        let scale = request.flatMap { field("scaleFactor", in: $0) as? CGFloat } ?? 2
        let display = request.flatMap { field("directDisplayID", in: $0) as? UInt32 }
        let preview = request.flatMap { field("isPreview", in: $0) as? Bool } ?? false
        let surface = id.flatMap(uuid) ?? UUID()
        DispatchQueue.main.async {
            // A preview in System Settings plays; the desktop waits for the agent to say it's locked or idle.
            guard let context = Surfaces.shared.acquire(surface, size: size, scale: scale, display: display, animates: preview),
                  let remote = Self.remoteContext(context) else {
                reply(nil, NSError(domain: "Keshiki", code: 1)); return
            }
            reply(remote, nil)
        }
    }

    /// Plays on the lock screen and as the screensaver while it's on screen. The desktop shows a still: there the
    /// app draws the scene itself.
    func update(withId id: Any?, request: Any?, reply: @escaping (Error?) -> Void) {
        let mode = request.flatMap { field("presentationMode", in: $0) }.map(caseName) ?? "default"
        let activity = request.flatMap { field("activityState", in: $0) }.map(caseName) ?? "active"
        if let surface = id.flatMap(uuid) {
            DispatchQueue.main.async { Surfaces.shared.update(surface, animates: activity == "active" && mode != "default") }
        }
        reply(nil)
    }

    func invalidate(withId id: Any?, reply: @escaping (Error?) -> Void) {
        if let surface = id.flatMap(uuid) {
            DispatchQueue.main.async { Surfaces.shared.invalidate(surface) }
        }
        reply(nil)
    }

    func snapshot(withId id: Any?, reply: @escaping (Any?, Error?) -> Void) {
        DispatchQueue.main.async { reply(Surfaces.shared.snapshot().flatMap(Self.snapshot), nil) }
    }

    func provideSettingsViewModels(withContentTypes types: Any?, reply: @escaping (Any?, Error?) -> Void) {
        DispatchQueue.main.async {
            reply(Surfaces.shared.thumbnail().flatMap(SettingsTile.viewModels), nil)
        }
    }

    func addChoiceRequest(withChoiceRequest request: Any?, onBehalfOfProcess process: Any?, reply: @escaping (Any?, Error?) -> Void) { reply(nil, nil) }
    func removeChoiceRequest(withChoiceRequest request: Any?, reply: @escaping (Error?) -> Void) { reply(nil) }
    func selectedChoicesDidChange(for id: Any?, reply: @escaping (Error?) -> Void) { reply(nil) }
    func invokeContextMenuAction(withMenuItemID menuItemID: Any?, groupItemID: Any?, reply: @escaping (Error?) -> Void) { reply(nil) }
    func isChoiceDownloaded(with choiceID: Any?, reply: @escaping (NSNumber?, Error?) -> Void) { reply(true, nil) }
    func download(withChoiceID choiceID: Any?, reply: (Error?) -> Void) -> Any? { reply(nil); return nil }
    func pauseDownload(for choiceID: Any?, reply: @escaping (Error?) -> Void) { reply(nil) }
    func cancelDownload(for choiceID: Any?, reply: @escaping (Error?) -> Void) { reply(nil) }
    func resumeDownload(for choiceID: Any?, reply: @escaping (Error?) -> Void) { reply(nil) }
    func removeDownload(for choiceID: Any?, reply: @escaping (Error?) -> Void) { reply(nil) }
    func migrateSelectedChoice(for id: Any?, reply: @escaping (Any?, Error?) -> Void) { reply(nil, nil) }
    func migrate(from: Any?, to: Any?, reply: @escaping (Error?) -> Void) { reply(nil) }
    func skipShuffledContent(withId id: Any?, reply: @escaping (Error?) -> Void) { reply(nil) }
    func canSkipShuffledContent(withId id: Any?, reply: @escaping (Bool, Error?) -> Void) { reply(false, nil) }
    func handleDebugRequest(for request: Any?, reply: @escaping (Any?, Error?) -> Void) { reply(nil, nil) }
    func handleNotification(withNamed name: Any?, reply: @escaping (Error?) -> Void) { reply(nil) }

    /// The agent's `WallpaperRemoteContextXPC` around our context id. The class has no initializer we can call,
    /// so the id is written into its `box` ivar.
    private static func remoteContext(_ contextID: UInt32) -> AnyObject? {
        guard let type = objc_getClass("WallpaperRemoteContextXPC") as? AnyClass, let object = class_createInstance(type, 0) else { return nil }
        let offset = class_getInstanceVariable(type, "box").map(ivar_getOffset) ?? 8
        guard offset + MemoryLayout<UInt32>.size <= class_getInstanceSize(type) else { return nil }
        Unmanaged.passUnretained(object as AnyObject).toOpaque().advanced(by: offset).storeBytes(of: contextID, as: UInt32.self)
        return object as AnyObject
    }

    /// The agent's `WallpaperSnapshotXPC`: an IOSurface pointer at offset 8.
    private static func snapshot(_ surface: IOSurface) -> AnyObject? {
        guard let type = objc_getClass("WallpaperSnapshotXPC") as? AnyClass, let object = class_createInstance(type, 0),
              8 + MemoryLayout<UnsafeRawPointer>.size <= class_getInstanceSize(type) else { return nil }
        Unmanaged.passUnretained(object as AnyObject).toOpaque().advanced(by: 8)
            .storeBytes(of: UnsafeRawPointer(Unmanaged.passRetained(surface).toOpaque()), as: UnsafeRawPointer.self)
        return object as AnyObject
    }
}

/// The first stored property called `label`, searched a few levels deep.
private func field(_ label: String, in value: Any, depth: Int = 0) -> Any? {
    guard depth < 8 else { return nil }
    for child in Mirror(reflecting: value).children {
        if child.label == label { return child.value }
        if let found = field(label, in: child.value, depth: depth + 1) { return found }
    }
    return nil
}

/// The surface a WallpaperID names.
private func uuid(in value: Any) -> UUID? {
    uuid(in: value, depth: 0)
}

private func uuid(in value: Any, depth: Int) -> UUID? {
    if let id = value as? UUID { return id }
    guard depth < 8 else { return nil }
    return Mirror(reflecting: value).children.lazy.compactMap { uuid(in: $0.value, depth: depth + 1) }.first
}

/// `.idle` → "idle", `.suspended(reason)` → "suspended".
private func caseName(_ value: Any) -> String {
    let mirror = Mirror(reflecting: value)
    if mirror.displayStyle == .enum, let label = mirror.children.first?.label { return label }
    return String(describing: value)
}
