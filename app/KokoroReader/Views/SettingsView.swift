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
            VStack(alignment: .leading, spacing: 16) {
                // Connection
                Section("Server") {
                    TextField("Server URL", text: $settings.serverURL)
                        .textFieldStyle(.roundedBorder)

                    HStack {
                        Button("Test Connection") { testConnection() }
                            .disabled(isTestingConnection)

                        switch connectionStatus {
                        case .unknown:
                            EmptyView()
                        case .connected:
                            Label("Connected", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                        case .failed(let msg):
                            Label(msg, systemImage: "xmark.circle.fill")
                                .foregroundStyle(.red)
                                .font(.caption)
                        }
                    }
                }

                Divider()

                // Voice & Speed
                Section("Voice") {
                    Picker("Voice", selection: $settings.voice) {
                        if availableVoices.isEmpty {
                            Text(settings.voice).tag(settings.voice)
                        }
                        ForEach(availableVoices, id: \.self) { voice in
                            Text(voice).tag(voice)
                        }
                    }

                    HStack {
                        Text("Speed: \(settings.speed, specifier: "%.1f")x")
                        Slider(value: $settings.speed, in: 0.5...2.0, step: 0.1)
                    }
                }

                Divider()

                // Playback
                Section("Playback") {
                    HStack {
                        Text("Skip interval: \(Int(settings.skipInterval))s")
                        Slider(value: $settings.skipInterval, in: 5...60, step: 5)
                    }
                }

                Divider()

                // Shortcuts
                Section("Shortcuts") {
                    ShortcutRow(label: "Read Selection", binding: settings.readSelectionShortcut)
                    ShortcutRow(label: "Play/Pause", binding: settings.playPauseShortcut)
                    ShortcutRow(label: "Stop", binding: settings.stopShortcut)
                    ShortcutRow(label: "Skip Forward", binding: settings.skipForwardShortcut)
                    ShortcutRow(label: "Skip Backward", binding: settings.skipBackwardShortcut)
                }

                Divider()

                // General
                Section("General") {
                    Toggle("Launch at login", isOn: $settings.launchAtLogin)

                    if !TextCaptureService.isAccessibilityTrusted {
                        Button("Grant Accessibility Access") {
                            TextCaptureService.requestAccessibility()
                        }
                        Text("Required for reading selected text from other apps")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
        }
        .frame(width: 300)
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
            Spacer()
            Text(shortcutDescription)
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
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

private struct Section<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            content
        }
    }
}
