import SwiftUI

@Observable
final class SettingsService {
    static let shared = SettingsService()

    var serverURL: String {
        didSet { UserDefaults.standard.set(serverURL, forKey: "serverURL") }
    }
    var apiKey: String {
        didSet { UserDefaults.standard.set(apiKey, forKey: "apiKey") }
    }
    var voice: String {
        didSet { UserDefaults.standard.set(voice, forKey: "voice") }
    }
    var speed: Double {
        didSet { UserDefaults.standard.set(speed, forKey: "speed") }
    }
    var skipInterval: Double {
        didSet { UserDefaults.standard.set(skipInterval, forKey: "skipInterval") }
    }
    var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
            updateLaunchAtLogin()
        }
    }

    // Shortcut bindings
    var readSelectionShortcut: ShortcutBinding {
        didSet { saveShortcut(readSelectionShortcut, key: "shortcut_readSelection") }
    }
    var playPauseShortcut: ShortcutBinding {
        didSet { saveShortcut(playPauseShortcut, key: "shortcut_playPause") }
    }
    var stopShortcut: ShortcutBinding {
        didSet { saveShortcut(stopShortcut, key: "shortcut_stop") }
    }
    var skipForwardShortcut: ShortcutBinding {
        didSet { saveShortcut(skipForwardShortcut, key: "shortcut_skipForward") }
    }
    var skipBackwardShortcut: ShortcutBinding {
        didSet { saveShortcut(skipBackwardShortcut, key: "shortcut_skipBackward") }
    }

    private init() {
        let defaults = UserDefaults.standard
        self.serverURL = defaults.string(forKey: "serverURL") ?? "http://localhost:8787"
        self.apiKey = defaults.string(forKey: "apiKey") ?? ""
        self.voice = defaults.string(forKey: "voice") ?? "af_heart"
        self.speed = defaults.double(forKey: "speed").nonZero ?? 1.0
        self.skipInterval = defaults.double(forKey: "skipInterval").nonZero ?? 10.0
        self.launchAtLogin = defaults.bool(forKey: "launchAtLogin")

        self.readSelectionShortcut = Self.loadShortcut(key: "shortcut_readSelection") ?? .defaultReadSelection
        self.playPauseShortcut = Self.loadShortcut(key: "shortcut_playPause") ?? .defaultPlayPause
        self.stopShortcut = Self.loadShortcut(key: "shortcut_stop") ?? .defaultStop
        self.skipForwardShortcut = Self.loadShortcut(key: "shortcut_skipForward") ?? .defaultSkipForward
        self.skipBackwardShortcut = Self.loadShortcut(key: "shortcut_skipBackward") ?? .defaultSkipBackward
    }

    private func saveShortcut(_ binding: ShortcutBinding, key: String) {
        if let data = try? JSONEncoder().encode(binding) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private static func loadShortcut(key: String) -> ShortcutBinding? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(ShortcutBinding.self, from: data)
    }

    private func updateLaunchAtLogin() {
        if launchAtLogin {
            SMAppService.register()
        } else {
            SMAppService.unregister()
        }
    }
}

private enum SMAppService {
    static func register() {
        if #available(macOS 13.0, *) {
            try? ServiceManagement.SMAppService.mainApp.register()
        }
    }
    static func unregister() {
        if #available(macOS 13.0, *) {
            try? ServiceManagement.SMAppService.mainApp.unregister()
        }
    }
}

import ServiceManagement

extension Double {
    var nonZero: Double? {
        self == 0 ? nil : self
    }
}
