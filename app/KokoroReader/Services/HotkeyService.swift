import Carbon
import Cocoa
import os.log

final class HotkeyService {
    static let shared = HotkeyService()

    var onReadSelection: (() -> Void)?
    var onPlayPause: (() -> Void)?
    var onStop: (() -> Void)?
    var onSkipForward: (() -> Void)?
    var onSkipBackward: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var watchdog: Timer?
    private var didPromptAccessibility = false
    private let settings = SettingsService.shared
    private let log = Logger(subsystem: "com.kokoro.reader", category: "hotkeys")

    func start() {
        createTapIfNeeded()
        startWatchdog()
    }

    // macOS silently disables event taps (App Nap, sleep/wake, slow callbacks),
    // and tap creation can fail at launch if accessibility isn't ready yet.
    // The watchdog recovers from both instead of dying silently.
    private func startWatchdog() {
        guard watchdog == nil else { return }
        watchdog = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.ensureTapAlive()
        }
    }

    private func ensureTapAlive() {
        if let tap = eventTap {
            if !CGEvent.tapIsEnabled(tap: tap) {
                log.warning("Event tap was disabled — re-enabling")
                FileLog.log("hotkeys: tap was disabled — watchdog re-enabled it")
                CGEvent.tapEnable(tap: tap, enable: true)
            }
        } else {
            createTapIfNeeded()
        }
    }

    func reenableTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }

    private func createTapIfNeeded() {
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
            log.error("Event tap creation failed (accessibility trusted: \(TextCaptureService.isAccessibilityTrusted)) — will retry")
            FileLog.log("hotkeys: tap creation FAILED (accessibility trusted: \(TextCaptureService.isAccessibilityTrusted)) — retrying every 10s")
            if !TextCaptureService.isAccessibilityTrusted && !didPromptAccessibility {
                didPromptAccessibility = true
                TextCaptureService.requestAccessibility()
            }
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        log.info("Event tap created and enabled")
        FileLog.log("hotkeys: tap created and enabled")
    }

    func stop() {
        watchdog?.invalidate()
        watchdog = nil
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

        // Dispatch handlers async: any real work inside the tap callback stalls it,
        // and macOS disables taps whose callbacks are slow (large selections did this).
        if matchesShortcut(keyCode: keyCode, flags: flags, binding: settings.readSelectionShortcut) {
            FileLog.log("hotkey: read-selection")
            DispatchQueue.main.async { self.onReadSelection?() }
            return true
        }
        if matchesShortcut(keyCode: keyCode, flags: flags, binding: settings.playPauseShortcut) {
            DispatchQueue.main.async { self.onPlayPause?() }
            return true
        }
        if matchesShortcut(keyCode: keyCode, flags: flags, binding: settings.stopShortcut) {
            DispatchQueue.main.async { self.onStop?() }
            return true
        }
        if matchesShortcut(keyCode: keyCode, flags: flags, binding: settings.skipForwardShortcut) {
            DispatchQueue.main.async { self.onSkipForward?() }
            return true
        }
        if matchesShortcut(keyCode: keyCode, flags: flags, binding: settings.skipBackwardShortcut) {
            DispatchQueue.main.async { self.onSkipBackward?() }
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
    guard let userInfo else {
        return Unmanaged.passRetained(event)
    }

    let service = Unmanaged<HotkeyService>.fromOpaque(userInfo).takeUnretainedValue()

    // The system disables the tap when the callback stalls or input state changes;
    // without re-enabling here, hotkeys die silently until app restart.
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        service.reenableTap()
        return Unmanaged.passRetained(event)
    }

    guard type == .keyDown else {
        return Unmanaged.passRetained(event)
    }
    if service.handleKeyEvent(event) {
        return nil // Consume the event
    }

    return Unmanaged.passRetained(event)
}
