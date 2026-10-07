import AppKit
import SwiftUI
import Carbon

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSMenuItemValidation {
    let preferences = Preferences()
    let session = DictationSession()
    let login = LoginItem()
    let monitor = FnMonitor()
    let updater = AppUpdater()
    private let shortcuts = GlobalShortcuts()
    private let permissionSetup = InitialPermissionSetup()
    private var settingsWindow: NSWindow?
    private var panel: NSPanel?
    private var statusItem: NSStatusItem?
    private var panelBottomCenter = NSPoint.zero
    func applicationDidFinishLaunching(_ notification: Notification) {
        updater.start()
        applyVisibility()
        monitor.shortcut = preferences.shortcut
        monitor.selectionShortcut = preferences.selectionShortcut
        monitor.holdToTalk = preferences.holdToTalk
        monitor.onSelection = { [weak self] in
            guard let self else { return }
            session.organizeSelection(preferences)
        }
        monitor.onCancelPrimary = { [weak self] in
            guard let self, session.phase == .recording || session.phase == .requesting else { return }
            session.discard(); session.onDismiss?()
        }
        monitor.onSelectionCaptured = { [weak self] value in self?.preferences.selectionShortcut = value }
        monitor.onTrigger = { [weak self] down in
            guard let self else { return }
            session.trigger(down: down, preferences: preferences)
        }
        monitor.onEscape = { [weak self] in self?.session.escape() ?? false }
        monitor.onCaptured = { [weak self] value in self?.preferences.shortcut = value }
        monitor.refresh()
        shortcuts.action = { [weak self] _ in self?.showSettings() }
        if !shortcuts.register() { session.error = "hotkeyFailed" }
        session.onPresentation = { [weak self] in self?.showPanel() }
        session.onDismiss = { [weak self] in self?.panel?.orderOut(nil) }
        let event = NSAppleEventManager.shared().currentAppleEvent
        let loginLaunch = event?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
        if !loginLaunch {
            if !monitor.accessibility { preferences.settingsTab = .permissions }
            showSettings()
        }
    }
    private func requestInitialPermissions() {
        Task { [weak self] in
            guard let self else { return }
            await permissionSetup.run(
                prepare: {
                    monitor.refresh()
                    if !monitor.accessibility || monitor.microphone != .authorized {
                        preferences.settingsTab = .permissions
                    }
                },
                requestMicrophone: { await monitor.requestInitialMicrophone() },
                requestAccessibility: {
                    monitor.refresh()
                    if !monitor.accessibility { monitor.requestAccessibility() }
                }
            )
        }
    }
    func applicationDidBecomeActive(_ notification: Notification) { monitor.refresh(); login.refresh() }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showSettings(); return false }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        Task {
            let saved = await preferences.credentials.flush()
            if !saved { preferences.settingsTab = .models; showSettings() }
            sender.reply(toApplicationShouldTerminate: saved)
        }
        return .terminateLater
    }
    func applicationWillTerminate(_ notification: Notification) { session.discard(); monitor.stop(); shortcuts.unregister() }
    func applyVisibility() {
        configureMenu()
        settingsWindow?.title = "\(preferences.t("app")) · \(preferences.t("settings"))"
        let policy: NSApplication.ActivationPolicy = preferences.showDock ? .regular : .accessory
        if NSApp.activationPolicy() != policy { NSApp.setActivationPolicy(policy) }
        if let settingsWindow { Self.configureSettingsVisibility(settingsWindow, showDock: preferences.showDock) }
        if preferences.showMenu {
            if statusItem == nil { statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength) }
            statusItem?.button?.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: preferences.t("app"))
            statusItem?.button?.image?.isTemplate = true
            let menu = NSMenu()
            menu.delegate = self
            statusItem?.menu = menu
        } else if let statusItem { NSStatusBar.system.removeStatusItem(statusItem); self.statusItem = nil }
    }
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.autoenablesItems = false
        addMenuItem(menu, title: preferences.t(session.phase == .recording ? "stop" : "record"), action: #selector(toggleRecording), enabled: session.phase == .ready || session.phase == .recording)
        addMenuItem(menu, title: preferences.t("cancel"), action: #selector(cancelRecording), enabled: session.busy || session.phase == .paused)
        if session.phase == .paused { addMenuItem(menu, title: preferences.t("resume"), action: #selector(resumeRecording)) }
        if session.hasAudio && session.phase == .ready {
            addMenuItem(menu, title: preferences.t("retry"), action: #selector(retryRecognition))
        }
        addMenuItem(menu, title: preferences.t("selectionPolish"), action: #selector(organizeSelectedText), enabled: !session.busy && session.phase != .paused)
        menu.addItem(.separator())
        addMenuItem(menu, title: preferences.t("copyLast"), action: #selector(copyLast), enabled: !session.lastResult.isEmpty)
        let polish = NSMenuItem(title: preferences.t("organizer"), action: nil, keyEquivalent: "")
        polish.isEnabled = !session.busy
        let modes = NSMenu(title: preferences.t("organizer"))
        modes.autoenablesItems = false
        let off = addMenuItem(modes, title: preferences.t("noOrganization"), action: #selector(selectPolishMode(_:)), enabled: !session.busy)
        off.representedObject = "off"
        off.state = preferences.autoOrganize ? .off : .on
        modes.addItem(.separator())
        for style in WritingStyle.allCases {
            let item = addMenuItem(modes, title: preferences.t(style.rawValue), action: #selector(selectPolishMode(_:)), enabled: !session.busy)
            item.representedObject = style.rawValue
            item.state = preferences.autoOrganize && preferences.style == style ? .on : .off
        }
        polish.submenu = modes
        menu.addItem(polish)
        menu.addItem(.separator())
        let settings = addMenuItem(menu, title: preferences.t("settings"), action: #selector(openSettings))
        hideSettingsIcon(settings)
        addMenuItem(menu, title: preferences.t("checkForUpdates"), action: #selector(checkForUpdates), enabled: updater.canCheckForUpdates)
        addMenuItem(menu, title: preferences.t("quit"), action: #selector(quitApp))
    }
    @discardableResult private func addMenuItem(_ menu: NSMenu, title: String, action: Selector, enabled: Bool = true) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self; item.isEnabled = enabled; menu.addItem(item); return item
    }
    @objc private func toggleRecording() { session.toggle(preferences) }
    @objc private func cancelRecording() { session.escape() }
    @objc private func resumeRecording() { session.resume(preferences) }
    @objc private func retryRecognition() { session.transcribe(preferences); showPanel() }
    @objc private func organizeSelectedText() { session.organizeSelection(preferences) }
    @objc private func copyLast() { session.copyLastResult() }
    @objc private func selectPolishMode(_ sender: NSMenuItem) {
        guard !session.busy, let value = sender.representedObject as? String else { return }
        if value == "off" { preferences.autoOrganize = false }
        else if let style = WritingStyle(rawValue: value) {
            preferences.style = style
            preferences.autoOrganize = true
        }
    }
    private func hideSettingsIcon(_ item: NSMenuItem) {
        item.image = nil
        if #available(macOS 27.0, *) { item.preferredImageVisibility = .hidden }
    }
    private func configureMenu() {
        let menu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu(title: preferences.t("app"))
        let about = NSMenuItem(title: preferences.t("about"), action: #selector(openAbout), keyEquivalent: "")
        about.target = self; appMenu.addItem(about)
        let updates = NSMenuItem(title: preferences.t("checkForUpdates"), action: #selector(checkForUpdates), keyEquivalent: "")
        updates.target = self; appMenu.addItem(updates)
        appMenu.addItem(.separator())
        let settings = NSMenuItem(title: preferences.t("settings"), action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self; hideSettingsIcon(settings); appMenu.addItem(settings)
        appMenu.addItem(.separator())
        let quit = NSMenuItem(title: preferences.t("quit"), action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self; appMenu.addItem(quit)
        appItem.submenu = appMenu; menu.addItem(appItem)
        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: preferences.t("edit"))
        for (title, selector, key) in [("undo", "undo:", "z"), ("cut", "cut:", "x"), ("copy", "copy:", "c"), ("pasteAction", "paste:", "v"), ("selectAll", "selectAll:", "a")] {
            editMenu.addItem(NSMenuItem(title: preferences.t(title), action: NSSelectorFromString(selector), keyEquivalent: key))
        }
        editItem.submenu = editMenu; menu.addItem(editItem)
        NSApp.mainMenu = menu
    }
    @objc private func openAbout() { showSettings(); preferences.settingsTab = .about }
    @objc private func checkForUpdates() { if updater.canCheckForUpdates { updater.checkForUpdates() } }
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        menuItem.action != #selector(checkForUpdates) || updater.canCheckForUpdates
    }
    @objc private func openSettings() { showSettings() }
    @objc private func quitApp() { NSApp.terminate(nil) }
    static func configureSettingsVisibility(_ window: NSWindow, showDock: Bool) {
        // Authorization UI can hide an accessory app while taking focus. Keep its
        // settings visible; regular Dock apps retain the normal Hide behavior.
        window.canHide = showDock
        window.hidesOnDeactivate = false
    }
    func showSettings() {
        login.refresh()
        if settingsWindow == nil {
            let view = SettingsView(preferences: preferences, login: login, monitor: monitor, updater: updater, applyVisibility: { [weak self] in self?.applyVisibility() })
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 816, height: preferences.settingsTab.windowHeight), styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView], backing: .buffered, defer: false)
            window.title = "\(preferences.t("app")) · \(preferences.t("settings"))"
            window.titlebarAppearsTransparent = true
            window.titlebarSeparatorStyle = .none
            let hostingView = NSHostingView(rootView: view)
            // The window owns resizing; SwiftUI must not jump to the next page's intrinsic size.
            hostingView.sizingOptions = []
            window.contentView = hostingView
            window.initialFirstResponder = window.contentView
            window.isReleasedWhenClosed = false
            Self.configureSettingsVisibility(window, showDock: preferences.showDock)
            window.center(); settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
        requestInitialPermissions()
    }
    private func resizePanel(_ size: CGSize) {
        panel?.setFrame(NSRect(x: panelBottomCenter.x - size.width / 2, y: panelBottomCenter.y, width: size.width, height: size.height), display: true)
    }
    private func showPanel() {
        if panel == nil {
            let view = DictationBar(preferences: preferences, session: session, openSettings: { [weak self] in self?.showSettings() }, dismiss: { [weak self] in self?.panel?.orderOut(nil) }, resize: { [weak self] size in self?.resizePanel(size) })
            let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 196, height: 60), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.level = .floating; panel.isOpaque = false; panel.backgroundColor = .clear
            panel.hasShadow = true; panel.hidesOnDeactivate = false
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.contentView = NSHostingView(rootView: view)
            self.panel = panel
        }
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        if let frame = screen?.visibleFrame {
            panelBottomCenter = NSPoint(x: frame.midX, y: frame.minY + 64)
            resizePanel(panel?.frame.size ?? CGSize(width: 196, height: 60))
        }
        panel?.orderFrontRegardless()
    }
}
