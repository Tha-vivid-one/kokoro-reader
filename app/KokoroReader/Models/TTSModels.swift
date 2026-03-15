import Foundation
import CoreGraphics

struct TTSRequest: Codable {
    let text: String
    let voice: String
    let speed: Double
}

struct VoicesResponse: Codable {
    let voices: [String]
}

struct HealthResponse: Codable {
    let status: String
    let model_loaded: Bool
}

enum TTSError: LocalizedError {
    case serverUnreachable
    case invalidResponse(Int)
    case noData
    case textTooLong
    case encodingError

    var errorDescription: String? {
        switch self {
        case .serverUnreachable: return "Cannot reach TTS server"
        case .invalidResponse(let code): return "Server returned \(code)"
        case .noData: return "No audio data received"
        case .textTooLong: return "Text exceeds 5000 character limit"
        case .encodingError: return "Failed to encode request"
        }
    }
}

enum PlayerState {
    case idle
    case loading
    case playing
    case paused
}

struct ShortcutBinding: Codable, Equatable {
    var keyCode: UInt16
    var modifiers: UInt64

    static let cmdShift: UInt64 = CGEventFlags([.maskCommand, .maskShift]).rawValue

    static let defaultReadSelection = ShortcutBinding(keyCode: 15, modifiers: cmdShift)  // ⌘⇧R
    static let defaultPlayPause = ShortcutBinding(keyCode: 35, modifiers: cmdShift)      // ⌘⇧P
    static let defaultStop = ShortcutBinding(keyCode: 1, modifiers: cmdShift)            // ⌘⇧S
    static let defaultSkipForward = ShortcutBinding(keyCode: 124, modifiers: cmdShift)   // ⌘⇧→
    static let defaultSkipBackward = ShortcutBinding(keyCode: 123, modifiers: cmdShift)  // ⌘⇧←
}
