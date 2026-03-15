import Carbon
import Cocoa

final class HotkeyService {
    static let shared = HotkeyService()

    var onReadSelection: (() -> Void)?
    var onPlayPause: (() -> Void)?
    var onStop: (() -> Void)?
    var onSkipForward: (() -> Void)?
    var onSkipBackward: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let settings = SettingsService.shared

    func start() {
        guard eventTap == nil else { return }

        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: hotkeyCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            if !TextCaptureService.isAccessibilityTrusted {
                TextCaptureService.requestAccessibility()
            }
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            }
        }
        eventTap = nil
        runLoopSource = nil
    }

    func handleKeyEvent(_ event: CGEvent) -> Bool {
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags

        if matchesShortcut(keyCode: keyCode, flags: flags, binding: settings.readSelectionShortcut) {
            onReadSelection?()
            return true
        }
        if matchesShortcut(keyCode: keyCode, flags: flags, binding: settings.playPauseShortcut) {
            onPlayPause?()
            return true
        }
        if matchesShortcut(keyCode: keyCode, flags: flags, binding: settings.stopShortcut) {
            onStop?()
            return true
        }
        if matchesShortcut(keyCode: keyCode, flags: flags, binding: settings.skipForwardShortcut) {
            onSkipForward?()
            return true
        }
        if matchesShortcut(keyCode: keyCode, flags: flags, binding: settings.skipBackwardShortcut) {
            onSkipBackward?()
            return true
        }

        return false
    }

    private func matchesShortcut(keyCode: UInt16, flags: CGEventFlags, binding: ShortcutBinding) -> Bool {
        let relevantFlags: CGEventFlags = [.maskCommand, .maskShift, .maskAlternate, .maskControl]
        let maskedFlags = flags.intersection(relevantFlags).rawValue
        let bindingFlags = CGEventFlags(rawValue: binding.modifiers).intersection(relevantFlags).rawValue
        return keyCode == binding.keyCode && maskedFlags == bindingFlags
    }
}

private func hotkeyCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard type == .keyDown, let userInfo else {
        return Unmanaged.passRetained(event)
    }

    let service = Unmanaged<HotkeyService>.fromOpaque(userInfo).takeUnretainedValue()
    if service.handleKeyEvent(event) {
        return nil // Consume the event
    }

    return Unmanaged.passRetained(event)
}
