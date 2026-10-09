import AppKit

@MainActor
protocol FrontmostAppMonitorDelegate: AnyObject {
    func frontmostAppMonitor(_ monitor: FrontmostAppMonitor, didActivate app: FrontmostApp)
}

/// Suit l'app au premier plan pour savoir à qui envoyer les raccourcis.
@MainActor
final class FrontmostAppMonitor {
    weak var delegate: FrontmostAppMonitorDelegate?

    private(set) var current: FrontmostApp?
    private var observer: NSObjectProtocol?

    func start() {
        update(with: NSWorkspace.shared.frontmostApplication)
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated { self?.update(with: app) }
        }
    }

    private func update(with app: NSRunningApplication?) {
        guard let app, app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
        let frontmost = FrontmostApp(name: app.localizedName ?? app.bundleIdentifier ?? "—", bundleID: app.bundleIdentifier)
        current = frontmost
        delegate?.frontmostAppMonitor(self, didActivate: frontmost)
    }
}
