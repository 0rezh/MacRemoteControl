import AppKit

@MainActor
protocol RemoteControllerDelegate: AnyObject {
    func remoteControllerDidUpdate(_ controller: RemoteController)
}

/// Le moteur de l'app : relie les téléphones (serveur), le clavier, la souris et les réglages.
/// C'est lui qui décide qui peut se connecter et quel raccourci envoyer à quelle app.
@MainActor
final class RemoteController {

    enum ServerStatus: Equatable {
        case starting
        case running
        case failed(String)
    }

    weak var delegate: RemoteControllerDelegate?

    private(set) var serverStatus: ServerStatus = .starting {
        didSet { notifyDelegate() }
    }

    private(set) var connectedClients = 0 {
        didSet { notifyDelegate() }
    }

    var hasAccessibility: Bool { accessibility.isTrusted }
    var frontmostApp: FrontmostApp? { appMonitor.current }
    var profile: AppProfile { AppProfile.forApp(bundleID: frontmostApp?.bundleID) }
    var addressMode: AddressMode { settings.addressMode }
    var keepsMacAwake: Bool { settings.keepsMacAwake }

    var pairingLink: PairingLink? {
        PairingLink(mode: settings.addressMode, port: Constants.Server.port, token: settings.token)
    }

    private let settings: SettingsStore
    private let keyboard = KeyboardManager()
    private let mouse = MouseManager()
    private let keepAwake = KeepAwakeManager()
    private let accessibility = AccessibilityManager()
    private let appMonitor = FrontmostAppMonitor()
    private var server: RemoteServer?

    init(settings: SettingsStore) {
        self.settings = settings
    }

    func start() {
        keepAwake.isEnabled = settings.keepsMacAwake
        accessibility.delegate = self
        accessibility.startMonitoring(every: Constants.Accessibility.pollInterval)
        appMonitor.delegate = self
        appMonitor.start()
        startServer()
    }

    func requestAccessibility() {
        accessibility.requestAccess()
    }

    func selectAddressMode(_ mode: AddressMode) {
        settings.addressMode = mode
        notifyDelegate()
    }

    func setKeepsMacAwake(_ isOn: Bool) {
        settings.keepsMacAwake = isOn
        keepAwake.isEnabled = isOn
        notifyDelegate()
    }

    /// Les téléphones déjà jumelés sont déconnectés et devront rescanner le QR code.
    func regenerateToken() {
        settings.token = PairingToken.generate()
        notifyDelegate()
        guard let server else { return }
        Task { await server.disconnectAll() }
    }

    private func startServer() {
        guard let webRoot = WebRootLocator.locate() else {
            serverStatus = .failed("Interface web introuvable (lance scripts/build.sh)")
            return
        }

        let port = Constants.Server.port
        let server = RemoteServer(port: port, webRoot: webRoot, delegate: self)
        self.server = server

        Task {
            do {
                try await server.run()
            } catch {
                serverStatus = .failed("Port \(port) indisponible : \(error.localizedDescription)")
            }
        }

        Task {
            do {
                try await server.waitUntilListening()
                if serverStatus == .starting { serverStatus = .running }
            } catch {
                if serverStatus == .starting { serverStatus = .failed("Le serveur n'a pas démarré sur le port \(port)") }
            }
        }
    }

    private var currentState: RemoteState {
        RemoteState(app: frontmostApp?.name ?? "—", profile: profile.name, accessibility: hasAccessibility)
    }

    private func broadcastState() {
        guard let server else { return }
        let state = currentState
        Task { await server.broadcast(state) }
    }

    private func notifyDelegate() {
        delegate?.remoteControllerDidUpdate(self)
    }
}

extension RemoteController: RemoteServerDelegate {
    func remoteServer(_ server: RemoteServer, shouldAcceptToken token: String) -> Bool {
        token == settings.token
    }

    func remoteServer(_ server: RemoteServer, didReceive action: RemoteAction) -> RemoteState {
        keyboard.perform(action, using: profile)
        return currentState
    }

    func remoteServer(_ server: RemoteServer, didReceive event: PointerEvent) {
        mouse.handle(event)
    }

    func remoteServer(_ server: RemoteServer, didReceive input: KeyboardInput) {
        keyboard.handle(input)
    }

    func remoteServerClientDidDisconnect(_ server: RemoteServer) {
        mouse.handle(.release)
        keyboard.releaseModifiers()
    }

    func remoteServerCurrentState(_ server: RemoteServer) -> RemoteState {
        currentState
    }

    func remoteServer(_ server: RemoteServer, didChangeClientCount count: Int) {
        connectedClients = count
    }
}

extension RemoteController: FrontmostAppMonitorDelegate {
    func frontmostAppMonitor(_ monitor: FrontmostAppMonitor, didActivate app: FrontmostApp) {
        broadcastState()
        notifyDelegate()
    }
}

extension RemoteController: AccessibilityManagerDelegate {
    func accessibilityManager(_ manager: AccessibilityManager, didChangeTrust isTrusted: Bool) {
        broadcastState()
        notifyDelegate()
    }
}
