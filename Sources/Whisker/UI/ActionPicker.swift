import AppKit
import Carbon.HIToolbox
import SwiftUI
import WhiskerCore

struct ActionPicker: View {
    let title: String
    @Binding var action: Action
    var defaultTitle = "Default"
    @State private var isRecording = false

    private enum Choice: Hashable {
        case action(Action)
        case shortcut
    }

    var body: some View {
        Picker(
            title,
            selection: Binding<Choice>(
                get: {
                    if isRecording { return .shortcut }
                    if case .shortcut = action { return .shortcut }
                    return .action(action)
                },
                set: { choice in
                    switch choice {
                    case .action(let newAction):
                        isRecording = false
                        action = newAction
                    case .shortcut:
                        isRecording = true
                    }
                })
        ) {
            Text(defaultTitle).tag(Choice.action(.passthrough))
            Text(Action.disabled.title).tag(Choice.action(.disabled))
            Section("Mouse") {
                ForEach(0..<5) { number in
                    Text(Action.mouseButton(number: number).title).tag(Choice.action(.mouseButton(number: number)))
                }
            }
            Section("System") {
                ForEach(SystemAction.allCases, id: \.self) { system in
                    Text(Action.system(action: system).title).tag(Choice.action(.system(action: system)))
                }
            }
            Section("Media") {
                ForEach(MediaKey.allCases, id: \.self) { key in
                    Text(Action.media(key: key).title).tag(Choice.action(.media(key: key)))
                }
            }
            Text("Keyboard shortcut").tag(Choice.shortcut)
        }

        if isRecording || action.isShortcut {
            ShortcutRecorder(action: $action, isRecording: $isRecording)
        }
    }
}

private struct ShortcutRecorder: View {
    @Binding var action: Action
    @Binding var isRecording: Bool
    @State private var monitor: Any?

    var body: some View {
        LabeledContent("Shortcut") {
            Button(isRecording ? "Type a shortcut…" : action.title) { isRecording = true }
        }
        .onChange(of: isRecording, initial: true) { _, isOn in isOn ? start() : stop() }
        .onDisappear { stop() }
    }

    private func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode != UInt16(kVK_Escape) {
                action = .shortcut(combo: KeyCombo(event))
            }
            isRecording = false
            return nil
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}

extension KeyCombo {
    init(_ event: NSEvent) {
        var modifiers: Modifiers = []
        var symbols = ""
        let flags = event.modifierFlags
        if flags.contains(.control) {
            modifiers.insert(.control)
            symbols += "⌃"
        }
        if flags.contains(.option) {
            modifiers.insert(.option)
            symbols += "⌥"
        }
        if flags.contains(.shift) {
            modifiers.insert(.shift)
            symbols += "⇧"
        }
        if flags.contains(.command) {
            modifiers.insert(.command)
            symbols += "⌘"
        }
        let key =
            Self.keyNames[Int(event.keyCode)]
            ?? event.charactersIgnoringModifiers?.uppercased()
            ?? "Key \(event.keyCode)"
        self.init(keyCode: event.keyCode, modifiers: modifiers, label: symbols + key)
    }

    private static let keyNames: [Int: String] = [
        kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_Return: "↩", kVK_Tab: "⇥", kVK_Space: "Space", kVK_Delete: "⌫", kVK_ForwardDelete: "⌦",
        kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
    ]
}

extension Action {
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
}
