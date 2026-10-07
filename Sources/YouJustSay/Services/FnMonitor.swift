import AppKit
import ApplicationServices
import Observation
import AVFoundation

@MainActor @Observable final class FnMonitor {
    var accessibility = AXIsProcessTrusted()
    var microphone = AVCaptureDevice.authorizationStatus(for: .audio)
    var lastChecked: Date?
    var repairingAccessibility = false
    var accessibilityRepairStatus: String?
    var running = false
    var capturing = false
    var shortcut = Shortcut.fn
    var selectionShortcut = Shortcut.fnSpace
    var holdToTalk = false
    var capturingSelection = false
    var captureError: String?
    var onSelection: (() -> Void)?
    var onSelectionCaptured: ((Shortcut) -> Void)?
    var onCancelPrimary: (() -> Void)?
    var onTrigger: ((Bool) -> Void)?
    var onEscape: (() -> Bool)?
    var onCaptured: ((Shortcut) -> Void)?
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var pressed = false
    private var selectionPressed = false
    private var suppressPrimary = false
    private var pendingPrimary = false
    private var pendingHold: Task<Void, Never>?
    private var candidateFlags: UInt64 = 0
    func refresh() {
        accessibility = AXIsProcessTrusted()
        microphone = AVCaptureDevice.authorizationStatus(for: .audio)
        lastChecked = Date()
        // This is a modifying (.defaultTap) event tap: macOS authorizes it
        // through Accessibility, not the separate listen-only permission.
        guard accessibility else {
            if pressed { onTrigger?(false) }
            stop()
            return
        }
        // Refreshing permissions must not interrupt an in-progress hold gesture.
        if let tap, CGEvent.tapIsEnabled(tap: tap) { running = true; return }
        stop()
        let mask = [CGEventType.flagsChanged, .keyDown, .keyUp].reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: mask, callback: { _, type, event, context in
            guard let context else { return Unmanaged.passUnretained(event) }
            let consumed = MainActor.assumeIsolated {
                Unmanaged<FnMonitor>.fromOpaque(context).takeUnretainedValue().handle(type, event: event)
            }
            return consumed ? nil : Unmanaged.passUnretained(event)
        }, userInfo: Unmanaged.passUnretained(self).toOpaque())
        guard let tap else { return }
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        running = true
    }
    func beginCapture(selection: Bool = false) {
        if pressed { onCancelPrimary?() }
        resetGesture()
        candidateFlags = 0; capturing = true; capturingSelection = selection; captureError = nil
    }
    func handle(_ type: CGEventType, event: CGEvent) -> Bool {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            if pressed { onTrigger?(false) }
            resetGesture()
            return false
        }
        let key = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags.intersection(Shortcut.allowedFlags)
        if capturing {
            if type == .keyDown && key == 53 { capturing = false; return true }
            if type == .flagsChanged {
                if flags.rawValue != 0 { candidateFlags = flags.rawValue }
                else if candidateFlags != 0 {
                    finishCapture(Shortcut(keyCode: nil, modifiers: candidateFlags, keyName: ""))
                }
            } else if type == .keyDown, flags.rawValue != 0 {
                let name = key == 49 ? "Space" : (NSEvent(cgEvent: event)?.charactersIgnoringModifiers?.uppercased() ?? "Key \(key)")
                let value = Shortcut(keyCode: key, modifiers: flags.rawValue, keyName: name)
                if !value.isReserved { finishCapture(value) }
                return true
            }
            return false
        }
        if type == .keyDown, key == 53, onEscape?() == true { return true }
        if let code = selectionShortcut.keyCode {
            if type == .keyDown, key == code, selectionShortcut.matches(flags: flags) {
                if !selectionPressed {
                    selectionPressed = true
                    suppressPrimary = true; pendingPrimary = false; pendingHold?.cancel()
                    if pressed { pressed = false; onCancelPrimary?() }
                    onSelection?()
                }
                return true
            }
            if selectionPressed, type == .keyUp, key == code {
                selectionPressed = false
                return true
            }
        } else if type == .flagsChanged {
            let down = selectionShortcut.matches(flags: flags)
            if down { selectionPressed = true }
            else if selectionPressed {
                selectionPressed = false; suppressPrimary = true; pendingPrimary = false; pendingHold?.cancel()
                if pressed { pressed = false; onCancelPrimary?() }
                if flags.rawValue == 0 { onSelection?() }
            }
        }
        if suppressPrimary {
            if flags.rawValue == 0 { suppressPrimary = false }
            return false
        }
        if let code = shortcut.keyCode {
            if type == .keyDown, key == code, shortcut.matches(flags: flags) {
                if !pressed { pressed = true; onTrigger?(true) }
                return true
            }
            if pressed && ((type == .keyUp && key == code) || (type == .flagsChanged && !shortcut.matches(flags: flags))) {
                pressed = false; onTrigger?(false)
                if type == .keyUp { return true }
            }
        } else {
            // Wait for release in toggle mode so Fn + Space doesn't also toggle recording.
            // Hold mode keeps a short grace period for the second key of a chord.
            if type == .keyDown && pendingPrimary {
                pendingPrimary = false; pendingHold?.cancel()
                if pressed { pressed = false; onCancelPrimary?() }
                suppressPrimary = true
            }
            if type == .flagsChanged {
                let down = shortcut.matches(flags: flags)
                if down && !pendingPrimary && !pressed {
                    pendingPrimary = true
                    if holdToTalk {
                        pendingHold = Task { [weak self] in
                            do { try await Task.sleep(for: .milliseconds(200)) } catch { return }
                            guard let self, pendingPrimary, !suppressPrimary else { return }
                            pressed = true; onTrigger?(true)
                        }
                    }
                } else if !down && (pendingPrimary || pressed) {
                    pendingHold?.cancel()
                    if pressed {
                        pressed = false
                        if flags.rawValue == 0 { onTrigger?(false) } else { onCancelPrimary?() }
                    }
                    else if pendingPrimary && flags.rawValue == 0 {
                        onTrigger?(true); onTrigger?(false)
                    }
                    if flags.rawValue != 0 { suppressPrimary = true }
                    pendingPrimary = false
                }
            }
        }
        return false
    }
    private func finishCapture(_ value: Shortcut) {
        let other = capturingSelection ? shortcut : selectionShortcut
        guard !value.conflicts(with: other) else {
            captureError = "shortcutConflict"; candidateFlags = 0; return
        }
        if capturingSelection { selectionShortcut = value; onSelectionCaptured?(value) }
        else { shortcut = value; onCaptured?(value) }
        capturing = false; candidateFlags = 0; resetGesture()
    }
    func requestAccessibility() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        openPrivacy("Privacy_Accessibility")
        refresh()
    }
    func requestInitialMicrophone() async {
        if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
            _ = await AVCaptureDevice.requestAccess(for: .audio)
        }
        refresh()
    }
    func requestMicrophone() {
        if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
            Task { _ = await AVCaptureDevice.requestAccess(for: .audio); refresh() }
        } else { openPrivacy("Privacy_Microphone") }
    }
    func manageAccessibility() { openPrivacy("Privacy_Accessibility") }
    func repairAccessibility() async {
        guard !repairingAccessibility else { return }
        repairingAccessibility = true
        accessibilityRepairStatus = nil
        defer { repairingAccessibility = false }
        do {
            guard try await AccessibilityRepair.reset(bundleID: Bundle.main.bundleIdentifier) else {
                accessibilityRepairStatus = "accessibilityRepairFailed"
                return
            }
            refresh()
            accessibilityRepairStatus = "accessibilityRepairReady"
            requestAccessibility()
        } catch { accessibilityRepairStatus = "accessibilityRepairFailed" }
    }
    private func openPrivacy(_ pane: String) {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)")!)
    }
    var microphoneStatusKey: String {
        switch microphone {
        case .authorized: "granted"
        case .notDetermined: "notGranted"
        case .denied: "notGranted"
        case .restricted: "restricted"
        @unknown default: "notGranted"
        }
    }
    func stop() {
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        source = nil; tap = nil; running = false; resetGesture()
    }
    private func resetGesture() {
        pendingHold?.cancel(); pendingHold = nil
        pressed = false; pendingPrimary = false; selectionPressed = false; suppressPrimary = false
    }
}
