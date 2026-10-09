import AppKit
import CoreGraphics

@MainActor
protocol AccessibilityManagerDelegate: AnyObject {
    func accessibilityManager(_ manager: AccessibilityManager, didChangeTrust isTrusted: Bool)
}

/// Permission « Accessibilité », nécessaire pour simuler le clavier et la souris.
@MainActor
final class AccessibilityManager {
    weak var delegate: AccessibilityManagerDelegate?

    private(set) var isTrusted = CGPreflightPostEventAccess()
    private var timer: Timer?

    /// Ajoute l'app à la liste Accessibilité et ouvre le bon panneau des Réglages.
    func requestAccess() {
        CGRequestPostEventAccess()
        NSWorkspace.shared.open(Constants.Accessibility.settingsURL)
    }

    /// macOS ne notifie pas quand la permission change : on vérifie à intervalle régulier.
    func startMonitoring(every interval: TimeInterval) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    private func refresh() {
        let trusted = CGPreflightPostEventAccess()
        guard trusted != isTrusted else { return }
        isTrusted = trusted
        delegate?.accessibilityManager(self, didChangeTrust: trusted)
    }
}
