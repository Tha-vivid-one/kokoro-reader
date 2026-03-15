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
            return text
        }
        // Fall back to clipboard
        return clipboardText()
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
