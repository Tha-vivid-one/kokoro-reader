import AppKit
import ApplicationServices

final class TextCaptureService {
    static let shared = TextCaptureService()

    static var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    static func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    func captureSelectedText() -> String? {
        // Try accessibility first
        if let text = getSelectedTextViaAccessibility(), !text.isEmpty {
            FileLog.log("capture: AX selection, \(text.count) chars")
            return text
        }
        // Browsers (Chrome/Safari) usually don't expose the selection via AX —
        // simulate ⌘C and grab it from the clipboard, then restore the clipboard.
        if let text = captureViaCommandC(), !text.isEmpty {
            FileLog.log("capture: ⌘C simulation, \(text.count) chars")
            return text
        }
        // Last resort: whatever is already in the clipboard (may be stale)
        let stale = clipboardText()
        FileLog.log("capture: AX + ⌘C both failed, using existing clipboard (\(stale?.count ?? 0) chars)")
        return stale
    }

    func capturePageText() -> String? {
        if let text = getFullTextViaAccessibility(), !text.isEmpty {
            return text
        }
        return clipboardText()
    }

    func clipboardText() -> String? {
        NSPasteboard.general.string(forType: .string)
    }

    /// Copies the frontmost app's selection by posting ⌘C, then restores the
    /// previous clipboard contents. Blocks up to ~500ms — call off the main thread.
    private func captureViaCommandC() -> String? {
        guard AXIsProcessTrusted() else {
            FileLog.log("capture: ⌘C skipped — accessibility not trusted")
            return nil
        }

        let pasteboard = NSPasteboard.general
        let saved = pasteboard.string(forType: .string)
        let savedChangeCount = pasteboard.changeCount

        let source = CGEventSource(stateID: .hidSystemState)
        let keyC: CGKeyCode = 8
        guard let cDown = CGEvent(keyboardEventSource: source, virtualKey: keyC, keyDown: true),
              let cUp = CGEvent(keyboardEventSource: source, virtualKey: keyC, keyDown: false) else {
            return nil
        }
        // Explicit flags so physically-held modifiers (⇧ from the hotkey) don't leak in
        cDown.flags = .maskCommand
        cUp.flags = .maskCommand
        cDown.post(tap: .cghidEventTap)
        cUp.post(tap: .cghidEventTap)

        // Wait for the target app to write the clipboard
        var copied: String?
        for _ in 0..<10 {
            usleep(50_000)
            if pasteboard.changeCount != savedChangeCount {
                copied = pasteboard.string(forType: .string)
                break
            }
        }

        // Restore what the user had on the clipboard
        if pasteboard.changeCount != savedChangeCount {
            pasteboard.clearContents()
            if let saved {
                pasteboard.setString(saved, forType: .string)
            }
        }

        if copied == nil {
            FileLog.log("capture: ⌘C produced no clipboard change (no selection?)")
        }
        return copied
    }

    // MARK: - Accessibility

    private func getSelectedTextViaAccessibility() -> String? {
        guard AXIsProcessTrusted() else { return nil }
        guard let focusedApp = NSWorkspace.shared.frontmostApplication else { return nil }

        let appElement = AXUIElementCreateApplication(focusedApp.processIdentifier)

        var focusedElement: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElement) == .success else {
            return nil
        }

        var selectedText: CFTypeRef?
        guard AXUIElementCopyAttributeValue(focusedElement as! AXUIElement, kAXSelectedTextAttribute as CFString, &selectedText) == .success else {
            return nil
        }

        return selectedText as? String
    }

    private func getFullTextViaAccessibility() -> String? {
        guard AXIsProcessTrusted() else { return nil }
        guard let focusedApp = NSWorkspace.shared.frontmostApplication else { return nil }

        let appElement = AXUIElementCreateApplication(focusedApp.processIdentifier)

        var focusedElement: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElement) == .success else {
            return nil
        }

        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(focusedElement as! AXUIElement, kAXValueAttribute as CFString, &value) == .success else {
            return nil
        }

        return value as? String
    }
}
