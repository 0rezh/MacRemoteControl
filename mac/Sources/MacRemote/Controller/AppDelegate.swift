import AppKit

/// Crée les objets de l'app et les passe aux contrôleurs.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var remoteController: RemoteController?
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let remoteController = RemoteController(settings: SettingsStore())
        let menuViewController = MenuViewController(remoteController: remoteController)
        statusItemController = StatusItemController(contentViewController: menuViewController)
        self.remoteController = remoteController

        remoteController.start()
    }
}
