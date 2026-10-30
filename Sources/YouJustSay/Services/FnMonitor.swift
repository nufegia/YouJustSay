import AppKit
@preconcurrency import ApplicationServices
import Observation
import AVFoundation
import OSLog

@MainActor @Observable final class FnMonitor {
    private let logger = Logger(subsystem: "app.youjustsay.native", category: "input-monitor")
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
    var onMonitoringDisabled: (() -> Void)?
    var onCancelPrimary: (() -> Void)?
    var onTrigger: ((Bool) -> Void)?
    var onEscape: (() -> Bool)?
    var onCaptured: ((Shortcut) -> Void)?
    private var insideEventCallback = false
    private var deliveryGeneration = 0
    private var suspensionCount = 0
    private var waitingForPrivacySettings = false
    private(set) var disabledAfterTimeout = false
    var suspended: Bool { suspensionCount > 0 }

    func suspend() {
        suspensionCount += 1
        stop()
        logger.notice("Input monitoring suspended; depth=\(self.suspensionCount)")
    }
    func resume() {
        guard suspensionCount > 0 else { return }
        suspensionCount -= 1
        logger.notice("Input monitoring resume requested; depth=\(self.suspensionCount)")
        if !suspended { refresh() }
    }
    private func emit(_ action: @escaping @MainActor () -> Void) {
        guard insideEventCallback else { action(); return }
        let generation = deliveryGeneration
        DispatchQueue.main.async { [weak self] in
            guard let self, self.deliveryGeneration == generation, !self.suspended, !self.disabledAfterTimeout else { return }
            action()
        }
    }
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var pressed = false
    private var selectionPressed = false
    private var suppressPrimary = false
    private var pendingPrimary = false
    private var pendingHold: Task<Void, Never>?
    private var candidateFlags: UInt64 = 0
    func refresh() {
        // Activation and SwiftUI appearance can fire during updater/auth dialogs.
        // Do not query TCC or recreate a tap while suspended.
        guard !suspended, !disabledAfterTimeout else { return }
        accessibility = AXIsProcessTrusted()
        microphone = AVCaptureDevice.authorizationStatus(for: .audio)
        lastChecked = Date()
        guard !suspended, !disabledAfterTimeout else { return }
        // This is a modifying (.defaultTap) event tap: macOS authorizes it
        // through Accessibility, not the separate listen-only permission.
        guard accessibility else {
            if pressed { emit { self.onTrigger?(false) } }
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
                let monitor = Unmanaged<FnMonitor>.fromOpaque(context).takeUnretainedValue()
                return monitor.handleEventTap(type, event: event)
            }
            return consumed ? nil : Unmanaged.passUnretained(event)
        }, userInfo: Unmanaged.passUnretained(self).toOpaque())
        guard let tap else {
            logger.error("Input event tap creation failed")
            return
        }
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        running = true
        logger.notice("Input event tap installed")
    }
    func handleEventTap(_ type: CGEventType, event: CGEvent) -> Bool {
        insideEventCallback = true
        defer { insideEventCallback = false }
        return handle(type, event: event)
    }
    func beginCapture(selection: Bool = false) {
        if pressed { emit { self.onCancelPrimary?() } }
        resetGesture()
        candidateFlags = 0; capturing = true; capturingSelection = selection; captureError = nil
    }
    func handle(_ type: CGEventType, event: CGEvent) -> Bool {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            // Fail open: never repeatedly rearm a tap that macOS disabled.
            guard !disabledAfterTimeout else { return false }
            logger.error("Input event tap disabled by system; event=\(type.rawValue)")
            disabledAfterTimeout = true
            stop()
            DispatchQueue.main.async { [weak self] in
                self?.onCancelPrimary?()
                self?.onMonitoringDisabled?()
            }
            return false
        }
        guard !suspended, !disabledAfterTimeout else { return false }
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
                    if pressed { pressed = false; emit { self.onCancelPrimary?() } }
                    emit { self.onSelection?() }
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
                if pressed { pressed = false; emit { self.onCancelPrimary?() } }
                if flags.rawValue == 0 { emit { self.onSelection?() } }
            }
        }
        if suppressPrimary {
            if flags.rawValue == 0 { suppressPrimary = false }
            return false
        }
        if let code = shortcut.keyCode {
            if type == .keyDown, key == code, shortcut.matches(flags: flags) {
                if !pressed { pressed = true; emit { self.onTrigger?(true) } }
                return true
            }
            if pressed && ((type == .keyUp && key == code) || (type == .flagsChanged && !shortcut.matches(flags: flags))) {
                pressed = false; emit { self.onTrigger?(false) }
                if type == .keyUp { return true }
            }
        } else {
            // Wait for release in toggle mode so Fn + Space doesn't also toggle recording.
            // Hold mode keeps a short grace period for the second key of a chord.
            if type == .keyDown && pendingPrimary {
                pendingPrimary = false; pendingHold?.cancel()
                if pressed { pressed = false; emit { self.onCancelPrimary?() } }
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
                            pressed = true; emit { self.onTrigger?(true) }
                        }
                    }
                } else if !down && (pendingPrimary || pressed) {
                    pendingHold?.cancel()
                    if pressed {
                        pressed = false
                        if flags.rawValue == 0 { emit { self.onTrigger?(false) } } else { emit { self.onCancelPrimary?() } }
                    }
                    else if pendingPrimary && flags.rawValue == 0 {
                        emit { self.onTrigger?(true) }; emit { self.onTrigger?(false) }
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
        if capturingSelection { selectionShortcut = value; emit { self.onSelectionCaptured?(value) } }
        else { shortcut = value; emit { self.onCaptured?(value) } }
        capturing = false; candidateFlags = 0; resetGesture()
    }
    func requestAccessibility() {
        suspend()
        defer { resume() }
        _ = AccessibilityRepair.registerCurrentApplication(Bundle.main.bundleURL)
        if AXIsProcessTrusted() {
            openPrivacy("Privacy_Accessibility")
        } else {
            // A settings deep link cannot recreate the TCC entry after a reset.
            // Request trust, then let the system alert open Settings instead of
            // opening a second window alongside the alert ourselves.
            beginPrivacyInteraction()
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
        }
        refresh()
    }
    func requestInitialMicrophone() async {
        suspend()
        defer { resume() }
        if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
            _ = await AVCaptureDevice.requestAccess(for: .audio)
        }
        refresh()
    }
    func requestMicrophone() {
        if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
            Task { await requestInitialMicrophone() }
        } else { openPrivacy("Privacy_Microphone") }
    }
    func manageAccessibility() { openPrivacy("Privacy_Accessibility") }
    func repairAccessibility() async {
        guard !repairingAccessibility else { return }
        suspend()
        defer { resume() }
        repairingAccessibility = true
        accessibilityRepairStatus = nil
        defer { repairingAccessibility = false }
        // Register the actual running bundle, not an installed copy with the same ID.
        _ = AccessibilityRepair.registerCurrentApplication(Bundle.main.bundleURL)
        let reset: Bool
        do { reset = try await AccessibilityRepair.reset(bundleID: Bundle.main.bundleIdentifier) }
        catch { reset = false }
        accessibility = AXIsProcessTrusted()
        lastChecked = Date()
        accessibilityRepairStatus = reset ? "accessibilityRepairReady" : "accessibilityRepairManual"
        // Always offer an actionable system-managed recovery path, even when tccutil is denied.
        if reset {
            requestAccessibility()
        } else {
            NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
            openPrivacy("Privacy_Accessibility")
        }
    }

    func resumeAfterPrivacySettings() {
        guard waitingForPrivacySettings else { return }
        waitingForPrivacySettings = false
        resume()
    }
    private func beginPrivacyInteraction() {
        if !waitingForPrivacySettings {
            waitingForPrivacySettings = true
            suspend()
        }
    }
    private func openPrivacy(_ pane: String) {
        beginPrivacyInteraction()
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
        let hadTap = tap != nil
        deliveryGeneration += 1
        capturing = false
        // Disable first: never leave an enabled tap without a servicing source.
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let tap { CFMachPortInvalidate(tap) }
        source = nil; tap = nil; running = false; resetGesture()
        if hadTap { logger.notice("Input event tap removed") }
    }
    private func resetGesture() {
        pendingHold?.cancel(); pendingHold = nil
        pressed = false; pendingPrimary = false; selectionPressed = false; suppressPrimary = false
    }
}
