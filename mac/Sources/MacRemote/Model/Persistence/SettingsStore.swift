import Foundation

/// Réglages persistants (UserDefaults).
final class SettingsStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if defaults.string(forKey: Constants.Defaults.token) == nil {
            defaults.set(PairingToken.generate(), forKey: Constants.Defaults.token)
        }
    }

    var token: String {
        get { defaults.string(forKey: Constants.Defaults.token) ?? "" }
        set { defaults.set(newValue, forKey: Constants.Defaults.token) }
    }

    var addressMode: AddressMode {
        get { AddressMode(rawValue: defaults.string(forKey: Constants.Defaults.addressMode) ?? "") ?? .bonjour }
        set { defaults.set(newValue.rawValue, forKey: Constants.Defaults.addressMode) }
    }

    var keepsMacAwake: Bool {
        get { defaults.object(forKey: Constants.Defaults.keepsMacAwake) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Constants.Defaults.keepsMacAwake) }
    }
}
