import Carbon

@MainActor final class GlobalShortcuts {
    private var references: [EventHotKeyRef] = []
    private var handler: EventHandlerRef?
    var action: ((UInt32) -> Void)?
    func register() -> Bool {
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        let result = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var id = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            guard status == noErr else { return status }
            let identifier = id.id
            MainActor.assumeIsolated {
                Unmanaged<GlobalShortcuts>.fromOpaque(context).takeUnretainedValue().action?(identifier)
            }
            return noErr
        }, 1, &type, context, &handler)
        guard result == noErr else { return false }
        // Ctrl + Option + Command + R / S. No keyboard monitoring permission needed.
        for (key, id) in [(UInt32(kVK_ANSI_S), UInt32(2))] {
            var reference: EventHotKeyRef?
            let status = RegisterEventHotKey(key, UInt32(controlKey | optionKey | cmdKey), EventHotKeyID(signature: 0x594A5359, id: id), GetApplicationEventTarget(), 0, &reference)
            guard status == noErr, let reference else { unregister(); return false }
            references.append(reference)
        }
        return true
    }
    func unregister() {
        for reference in references { UnregisterEventHotKey(reference) }
        references.removeAll()
        if let handler { RemoveEventHandler(handler) }
        handler = nil
    }
}
