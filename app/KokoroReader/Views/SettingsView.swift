import SwiftUI

struct SettingsView: View {
    @Bindable var settings: SettingsService
    @State private var availableVoices: [String] = []
    @State private var connectionStatus: ConnectionStatus = .unknown
    @State private var isTestingConnection = false

    enum ConnectionStatus {
        case unknown, connected, failed(String)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // Server
                SettingsSection("Server") {
                    TextField("Server URL", text: $settings.serverURL)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(KokoroTheme.bgSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(KokoroTheme.border, lineWidth: 1)
                        )
                        .foregroundStyle(KokoroTheme.textPrimary)
                        .font(.system(size: 12))

                    HStack(spacing: 8) {
                        Button("Test Connection") { testConnection() }
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(KokoroTheme.accent)
                            .disabled(isTestingConnection)

                        switch connectionStatus {
                        case .unknown:
                            EmptyView()
                        case .connected:
                            HStack(spacing: 3) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Connected")
                            }
                            .font(.system(size: 10))
                            .foregroundStyle(KokoroTheme.success)
                        case .failed(let msg):
                            HStack(spacing: 3) {
                                Image(systemName: "xmark.circle.fill")
                                Text(msg)
                            }
                            .font(.system(size: 10))
                            .foregroundStyle(KokoroTheme.error)
                            .lineLimit(1)
                        }
                    }
                }

                Divider().overlay(KokoroTheme.border)

                // Voice & Speed
                SettingsSection("Voice") {
                    Picker("Voice", selection: $settings.voice) {
                        if availableVoices.isEmpty {
                            Text(settings.voice).tag(settings.voice)
                        }
                        ForEach(availableVoices, id: \.self) { voice in
                            Text(voice).tag(voice)
                        }
                    }
                    .foregroundStyle(KokoroTheme.textPrimary)

                    HStack(spacing: 8) {
                        Text("Speed")
                            .font(.system(size: 12))
                            .foregroundStyle(KokoroTheme.textSecondary)
                        Slider(value: $settings.speed, in: 0.5...2.0, step: 0.1)
                            .tint(KokoroTheme.accent)
                        Text("\(settings.speed, specifier: "%.1f")x")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(KokoroTheme.textSecondary)
                            .frame(width: 30)
                    }
                }

                Divider().overlay(KokoroTheme.border)

                // Playback
                SettingsSection("Playback") {
                    HStack(spacing: 8) {
                        Text("Skip interval")
                            .font(.system(size: 12))
                            .foregroundStyle(KokoroTheme.textSecondary)
                        Slider(value: $settings.skipInterval, in: 5...60, step: 5)
                            .tint(KokoroTheme.accent)
                        Text("\(Int(settings.skipInterval))s")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(KokoroTheme.textSecondary)
                            .frame(width: 24)
                    }
                }

                Divider().overlay(KokoroTheme.border)

                // Shortcuts
                SettingsSection("Shortcuts") {
                    VStack(spacing: 4) {
                        ShortcutRow(label: "Read Selection", binding: settings.readSelectionShortcut)
                        ShortcutRow(label: "Play/Pause", binding: settings.playPauseShortcut)
                        ShortcutRow(label: "Stop", binding: settings.stopShortcut)
                        ShortcutRow(label: "Skip Forward", binding: settings.skipForwardShortcut)
                        ShortcutRow(label: "Skip Backward", binding: settings.skipBackwardShortcut)
                    }
                }

                Divider().overlay(KokoroTheme.border)

                // General
                SettingsSection("General") {
                    Toggle("Launch at login", isOn: $settings.launchAtLogin)
                        .font(.system(size: 12))
                        .foregroundStyle(KokoroTheme.textPrimary)
                        .tint(KokoroTheme.accent)

                    if !TextCaptureService.isAccessibilityTrusted {
                        Button("Grant Accessibility Access") {
                            TextCaptureService.requestAccessibility()
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(KokoroTheme.accent)

                        Text("Required for reading selected text from other apps")
                            .font(.system(size: 10))
                            .foregroundStyle(KokoroTheme.textMuted)
                    }
                }
            }
            .padding(14)
        }
        .frame(width: 300)
        .background(KokoroTheme.bgBase)
        .task { await loadVoices() }
    }

    private func testConnection() {
        isTestingConnection = true
        connectionStatus = .unknown
        Task {
            do {
                let health = try await TTSService.shared.checkHealth()
                connectionStatus = health.model_loaded ? .connected : .failed("Model not loaded")
            } catch {
                connectionStatus = .failed(error.localizedDescription)
            }
            isTestingConnection = false
        }
    }

    private func loadVoices() async {
        do {
            availableVoices = try await TTSService.shared.fetchVoices()
        } catch {
            // Keep current voice as only option
        }
    }
}

private struct ShortcutRow: View {
    let label: String
    let binding: ShortcutBinding

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(KokoroTheme.textSecondary)
            Spacer()
            Text(shortcutDescription)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(KokoroTheme.textPrimary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(KokoroTheme.bgElevated)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(KokoroTheme.border, lineWidth: 1)
                )
        }
    }

    private var shortcutDescription: String {
        var parts: [String] = []
        let flags = CGEventFlags(rawValue: binding.modifiers)
        if flags.contains(.maskCommand) { parts.append("⌘") }
        if flags.contains(.maskShift) { parts.append("⇧") }
        if flags.contains(.maskAlternate) { parts.append("⌥") }
        if flags.contains(.maskControl) { parts.append("⌃") }

        let keyName: String
        switch binding.keyCode {
        case 15: keyName = "R"
        case 35: keyName = "P"
        case 1: keyName = "S"
        case 124: keyName = "→"
        case 123: keyName = "←"
        default: keyName = "Key\(binding.keyCode)"
        }
        parts.append(keyName)

        return parts.joined()
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .kokoroSectionHeader()
            content
        }
    }
}
