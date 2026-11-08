import AppKit
import Carbon.HIToolbox
import WhiskerCore

/// Turns actions into synthetic events. Every event it posts carries `syntheticMarker` so the tap ignores it.
struct ActionPerformer: Sendable {
    static let syntheticMarker: Int64 = 0x5748_534B

    func perform(_ action: Action, at location: CGPoint) {
        switch action {
        case .passthrough, .disabled:
            return
        case .mouseButton(let number):
            postMouseButton(number, isDown: true, at: location)
            postMouseButton(number, isDown: false, at: location)
        case .shortcut(let combo):
            postKey(combo.keyCode, modifiers: combo.modifiers)
        case .system(let action):
            perform(action)
        case .media(let key):
            postMediaKey(key)
        }
    }

    func postMouseButton(_ number: Int, isDown: Bool, at location: CGPoint) {
        let type: CGEventType
        switch number {
        case 0: type = isDown ? .leftMouseDown : .leftMouseUp
        case 1: type = isDown ? .rightMouseDown : .rightMouseUp
        default: type = isDown ? .otherMouseDown : .otherMouseUp
        }
        let button = CGMouseButton(rawValue: UInt32(number)) ?? .center
        guard
            let event = CGEvent(
                mouseEventSource: nil, mouseType: type, mouseCursorPosition: location, mouseButton: button)
        else { return }
        event.setIntegerValueField(.mouseEventButtonNumber, value: Int64(number))
        event.setIntegerValueField(.eventSourceUserData, value: Self.syntheticMarker)
        event.post(tap: .cghidEventTap)
    }

    private func perform(_ action: SystemAction) {
        switch action {
        case .missionControl:
            // Opening the app works even when the user turned off the ⌃↑ shortcut.
            NSWorkspace.shared.open(URL(filePath: "/System/Applications/Mission Control.app"))
        case .appExpose: postKey(UInt16(kVK_DownArrow), modifiers: .control)
        case .showDesktop: postKey(UInt16(kVK_F11), modifiers: [])
        case .spaceLeft: postKey(UInt16(kVK_LeftArrow), modifiers: .control)
        case .spaceRight: postKey(UInt16(kVK_RightArrow), modifiers: .control)
        case .navigateBack: postKey(UInt16(kVK_ANSI_LeftBracket), modifiers: .command)
        case .navigateForward: postKey(UInt16(kVK_ANSI_RightBracket), modifiers: .command)
        }
    }

    private func postKey(_ keyCode: UInt16, modifiers: Modifiers) {
        let source = CGEventSource(stateID: .hidSystemState)
        for isDown in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: isDown) else { return }
            event.flags = Self.flags(for: keyCode, modifiers: modifiers)
            event.post(tap: .cghidEventTap)
        }
    }

    private static let arrowKeys: Set<Int> = [kVK_LeftArrow, kVK_RightArrow, kVK_UpArrow, kVK_DownArrow]
    private static let functionKeys: Set<Int> = [
        kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10, kVK_F11, kVK_F12,
    ]

    private static func flags(for keyCode: UInt16, modifiers: Modifiers) -> CGEventFlags {
        var flags: CGEventFlags = []
        if modifiers.contains(.command) { flags.insert(.maskCommand) }
        if modifiers.contains(.option) { flags.insert(.maskAlternate) }
        if modifiers.contains(.control) { flags.insert(.maskControl) }
        if modifiers.contains(.shift) { flags.insert(.maskShift) }
        // Space switching and Show Desktop ignore arrow and F-keys that lack the flags a real keyboard sends.
        if arrowKeys.contains(Int(keyCode)) { flags.formUnion([.maskSecondaryFn, .maskNumericPad]) }
        if functionKeys.contains(Int(keyCode)) { flags.insert(.maskSecondaryFn) }
        return flags
    }

    private func postMediaKey(_ key: MediaKey) {
        let code: Int
        switch key {
        case .volumeUp: code = Int(NX_KEYTYPE_SOUND_UP)
        case .volumeDown: code = Int(NX_KEYTYPE_SOUND_DOWN)
        case .mute: code = Int(NX_KEYTYPE_MUTE)
        case .playPause: code = Int(NX_KEYTYPE_PLAY)
        case .nextTrack: code = Int(NX_KEYTYPE_NEXT)
        case .previousTrack: code = Int(NX_KEYTYPE_PREVIOUS)
        }
        for state in [0xA00, 0xB00] {
            let event = NSEvent.otherEvent(
                with: .systemDefined, location: .zero, modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(state)),
                timestamp: 0, windowNumber: 0, context: nil, subtype: 8, data1: (code << 16) | state, data2: -1)
            event?.cgEvent?.post(tap: .cghidEventTap)
        }
    }
}
