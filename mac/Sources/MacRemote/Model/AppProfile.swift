/// Raccourcis à envoyer selon l'app au premier plan.
/// Play/pause et le son passent par les touches média (marchent partout) ;
/// avancer/reculer/plein écran dépendent de l'app, d'où ces profils.
struct AppProfile: Sendable {
    let name: String
    let seekBackward: Shortcut
    let seekForward: Shortcut
    let fullscreen: Shortcut

    /// YouTube, Netflix, Prime Video… : flèches pour avancer/reculer, `F` pour le plein écran.
    static let browser = AppProfile(
        name: "Navigateur",
        seekBackward: Shortcut(key: KeyCode.left),
        seekForward: Shortcut(key: KeyCode.right),
        fullscreen: Shortcut(key: KeyCode.f)
    )

    static let vlc = AppProfile(
        name: "VLC",
        seekBackward: Shortcut(key: KeyCode.left, flags: .maskCommand),
        seekForward: Shortcut(key: KeyCode.right, flags: .maskCommand),
        fullscreen: Shortcut(key: KeyCode.f, flags: .maskCommand)
    )

    /// IINA, QuickTime et la plupart des apps macOS : flèches + plein écran standard (⌃⌘F).
    static let standard = AppProfile(
        name: "Standard",
        seekBackward: Shortcut(key: KeyCode.left),
        seekForward: Shortcut(key: KeyCode.right),
        fullscreen: Shortcut(key: KeyCode.f, flags: [.maskControl, .maskCommand])
    )

    private static let browserBundleIDs: Set<String> = [
        "com.apple.Safari",
        "com.apple.SafariTechnologyPreview",
        "com.google.Chrome",
        "company.thebrowser.Browser",
        "company.thebrowser.dia",
        "org.mozilla.firefox",
        "com.brave.Browser",
        "com.microsoft.edgemac",
        "com.operasoftware.Opera",
        "com.vivaldi.Vivaldi",
        "app.zen-browser.zen",
    ]

    static func forApp(bundleID: String?) -> AppProfile {
        guard let bundleID else { return .standard }
        if browserBundleIDs.contains(bundleID) { return .browser }
        if bundleID == "org.videolan.vlc" { return .vlc }
        return .standard
    }
}
