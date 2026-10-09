import AppKit

/// Contrôleur du menu : traduit l'état de `RemoteController` en valeurs pour `MenuView`,
/// et transforme les actions de la vue en appels au `RemoteController`.
@MainActor
final class MenuViewController: NSViewController {

    private let remoteController: RemoteController
    private var qrCodeCache: (url: String, image: NSImage)?

    private var menuView: MenuView {
        view as! MenuView
    }

    init(remoteController: RemoteController) {
        self.remoteController = remoteController
        super.init(nibName: nil, bundle: nil)
        remoteController.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) n'est pas utilisé")
    }

    override func loadView() {
        let menuView = MenuView()
        menuView.delegate = self
        view = menuView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        render()
    }

    private func render() {
        guard isViewLoaded else { return }
        menuView.configure(with: makeContent())
        preferredContentSize = menuView.fittingSize
    }

    private func makeContent() -> MenuView.Content {
        let isRunning = remoteController.serverStatus == .running
        let link = remoteController.pairingLink
        let (status, statusText) = statusDisplay

        return MenuView.Content(
            status: status,
            statusText: statusText,
            showsAccessibilityWarning: !remoteController.hasAccessibility,
            showsPairing: isRunning,
            qrCode: link.flatMap { qrCode(for: $0.url) },
            pairingMessage: isRunning && link == nil ? "Pas de réseau local détecté" : nil,
            addressOptions: AddressMode.allCases.map(title(for:)),
            selectedAddressOption: AddressMode.allCases.firstIndex(of: remoteController.addressMode) ?? 0,
            connectedPhones: "\(remoteController.connectedClients)",
            targetApp: remoteController.frontmostApp?.name ?? "—",
            shortcutProfile: remoteController.profile.name,
            keepsMacAwake: remoteController.keepsMacAwake
        )
    }

    private var statusDisplay: (MenuView.Status, String) {
        switch remoteController.serverStatus {
        case .starting:
            (.pending, "Démarrage…")
        case .running:
            (remoteController.hasAccessibility ? .ready : .warning, "Port \(Constants.Server.port)")
        case .failed(let message):
            (.failure, message)
        }
    }

    private func title(for mode: AddressMode) -> String {
        switch mode {
        case .bonjour: "Nom .local"
        case .ip: "Adresse IP"
        }
    }

    /// Le menu est re-rendu à chaque changement d'app : on ne régénère le QR code que si le lien change.
    private func qrCode(for url: String) -> NSImage? {
        if let cache = qrCodeCache, cache.url == url { return cache.image }
        guard let image = QRCodeGenerator.image(for: url, dimension: MenuView.qrDimension) else { return nil }
        qrCodeCache = (url, image)
        return image
    }
}

extension MenuViewController: RemoteControllerDelegate {
    func remoteControllerDidUpdate(_ controller: RemoteController) {
        render()
    }
}

extension MenuViewController: MenuViewDelegate {
    func menuViewDidRequestAccessibilitySettings(_ menuView: MenuView) {
        remoteController.requestAccessibility()
    }

    func menuView(_ menuView: MenuView, didSelectAddressOptionAt index: Int) {
        guard AddressMode.allCases.indices.contains(index) else { return }
        remoteController.selectAddressMode(AddressMode.allCases[index])
    }

    func menuViewDidRequestCopyLink(_ menuView: MenuView) {
        guard let url = remoteController.pairingLink?.url else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url, forType: .string)
    }

    func menuView(_ menuView: MenuView, didToggleKeepAwake isOn: Bool) {
        remoteController.setKeepsMacAwake(isOn)
    }

    func menuViewDidRequestNewToken(_ menuView: MenuView) {
        remoteController.regenerateToken()
    }

    func menuViewDidRequestQuit(_ menuView: MenuView) {
        NSApp.terminate(nil)
    }
}
