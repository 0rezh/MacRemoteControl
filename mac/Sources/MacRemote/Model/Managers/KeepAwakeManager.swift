import Foundation

/// Empêche la veille automatique (l'écran peut s'éteindre, le Mac reste joignable).
/// Ne remplace pas un écran externe : capot fermé sans écran, le Mac dort quand même.
final class KeepAwakeManager {
    private var activity: NSObjectProtocol?

    var isEnabled = false {
        didSet {
            guard isEnabled != oldValue else { return }
            if isEnabled {
                activity = ProcessInfo.processInfo.beginActivity(
                    options: [.idleSystemSleepDisabled],
                    reason: "Mac Remote : rester joignable depuis le téléphone"
                )
            } else if let activity {
                ProcessInfo.processInfo.endActivity(activity)
                self.activity = nil
            }
        }
    }
}
