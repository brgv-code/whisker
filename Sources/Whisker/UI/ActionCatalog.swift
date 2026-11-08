import AppKit
import Carbon.HIToolbox
import WhiskerCore

struct ActionSection: Identifiable {
    let title: String
    let actions: [Action]
    var id: String { title }
}

extension Action {
    static let sections = [
        ActionSection(title: "Mouse", actions: (0..<5).map { .mouseButton(number: $0) }),
        ActionSection(title: "System", actions: SystemAction.allCases.map { .system(action: $0) }),
        ActionSection(title: "Media", actions: MediaKey.allCases.map { .media(key: $0) }),
    ]

    var isShortcut: Bool {
        if case .shortcut = self { true } else { false }
    }

    var title: String {
        switch self {
        case .passthrough: "Default"
        case .disabled: "Do nothing"
        case .shortcut(let combo): combo.label
        case .mouseButton(let number):
            switch number {
            case 0: "Left click"
            case 1: "Right click"
            case 2: "Middle click"
            case 3: "Back button"
            case 4: "Forward button"
            default: "Button \(number + 1)"
            }
        case .system(let system):
            switch system {
            case .missionControl: "Mission Control"
            case .appExpose: "App Exposé"
            case .showDesktop: "Show Desktop"
            case .spaceLeft: "Desktop on the left"
            case .spaceRight: "Desktop on the right"
            case .navigateBack: "Back (⌘[)"
            case .navigateForward: "Forward (⌘])"
            case .nextTab: "Next tab"
            case .previousTab: "Previous tab"
            case .toggleFullScreen: "Full screen"
            }
        case .media(let key):
            switch key {
            case .playPause: "Play / Pause"
            case .nextTrack: "Next track"
            case .previousTrack: "Previous track"
            case .volumeUp: "Volume up"
            case .volumeDown: "Volume down"
            case .mute: "Mute"
            }
        }
    }

    var symbol: String {
        switch self {
        case .passthrough: "circle.dashed"
        case .disabled: "nosign"
        case .shortcut: "keyboard"
        case .mouseButton(let number):
            switch number {
            case 0, 1: "cursorarrow.click"
            case 3: "chevron.backward.circle"
            case 4: "chevron.forward.circle"
            default: "computermouse"
            }
        case .system(let system):
            switch system {
            case .missionControl: "rectangle.3.group"
            case .appExpose: "rectangle.stack"
            case .showDesktop: "menubar.dock.rectangle"
            case .spaceLeft: "arrow.left.square"
            case .spaceRight: "arrow.right.square"
            case .navigateBack: "arrow.backward"
            case .navigateForward: "arrow.forward"
            case .nextTab: "arrow.right.to.line"
            case .previousTab: "arrow.left.to.line"
            case .toggleFullScreen: "arrow.up.left.and.arrow.down.right"
            }
        case .media(let key):
            switch key {
            case .playPause: "playpause"
            case .nextTrack: "forward"
            case .previousTrack: "backward"
            case .volumeUp: "speaker.wave.3"
            case .volumeDown: "speaker.wave.1"
            case .mute: "speaker.slash"
            }
        }
    }

    static func defaultTitle(button number: Int, profile: DeviceProfile?) -> String {
        guard let keystroke = profile?.buttons.first(where: { $0.number == number })?.sends else {
            return mouseButton(number: number).title
        }
        return SystemAction(keystroke).map { Action.system(action: $0).title } ?? keystroke.label
    }

    func title(default defaultTitle: String) -> String {
        self == .passthrough ? defaultTitle : title
    }
}

extension ButtonBinding {
    func summary(default defaultTitle: String) -> String {
        switch self {
        case .action(let action): action.title(default: defaultTitle)
        case .tapOrHold(let tap, let hold):
            "\(tap.title(default: defaultTitle)) · Hold: \(hold.title(default: defaultTitle))"
        case .gesture: "Gesture button"
        }
    }
}

extension Keystroke {
    var label: String {
        var symbols = ""
        if modifiers.contains(.control) { symbols += "⌃" }
        if modifiers.contains(.option) { symbols += "⌥" }
        if modifiers.contains(.shift) { symbols += "⇧" }
        if modifiers.contains(.command) { symbols += "⌘" }
        let character = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)
            .flatMap { NSEvent(cgEvent: $0)?.charactersIgnoringModifiers?.uppercased() }
        return symbols + (KeyCombo.keyNames[Int(keyCode)] ?? character ?? "Key \(keyCode)")
    }
}

extension KeyCombo {
    init(_ event: NSEvent) {
        var modifiers: Modifiers = []
        let flags = event.modifierFlags
        if flags.contains(.control) { modifiers.insert(.control) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        if flags.contains(.command) { modifiers.insert(.command) }
        let keystroke = Keystroke(keyCode: event.keyCode, modifiers: modifiers)
        self.init(keyCode: event.keyCode, modifiers: modifiers, label: keystroke.label)
    }

    fileprivate static let keyNames: [Int: String] = [
        kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_Return: "↩", kVK_Tab: "⇥", kVK_Space: "Space", kVK_Delete: "⌫", kVK_ForwardDelete: "⌦",
        kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
    ]
}
