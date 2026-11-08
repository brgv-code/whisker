import AppKit
import Carbon.HIToolbox
import WhiskerCore

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
            postKey(Keystroke(keyCode: combo.keyCode, modifiers: combo.modifiers))
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
        event.flags = []
        event.post(tap: .cghidEventTap)
    }

    private func perform(_ action: SystemAction) {
        if let keystroke = action.keystroke {
            postKey(keystroke)
        } else {
            NSWorkspace.shared.open(URL(filePath: "/System/Applications/Mission Control.app"))
        }
    }

    private func postKey(_ keystroke: Keystroke) {
        postKey(keystroke, isDown: true)
        postKey(keystroke, isDown: false)
    }

    func postKey(_ keystroke: Keystroke, isDown: Bool) {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let event = CGEvent(keyboardEventSource: source, virtualKey: keystroke.keyCode, keyDown: isDown) else {
            return
        }
        event.flags = Self.flags(for: keystroke.keyCode, modifiers: keystroke.modifiers)
        event.setIntegerValueField(.eventSourceUserData, value: Self.syntheticMarker)
        event.post(tap: .cghidEventTap)
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

extension Modifiers {
    init(_ flags: CGEventFlags) {
        self = []
        if flags.contains(.maskCommand) { insert(.command) }
        if flags.contains(.maskAlternate) { insert(.option) }
        if flags.contains(.maskControl) { insert(.control) }
        if flags.contains(.maskShift) { insert(.shift) }
    }
}
