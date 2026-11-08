public struct Modifiers: OptionSet, Hashable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let command = Modifiers(rawValue: 1 << 0)
    public static let option = Modifiers(rawValue: 1 << 1)
    public static let control = Modifiers(rawValue: 1 << 2)
    public static let shift = Modifiers(rawValue: 1 << 3)

    private static let names: [(String, Modifiers)] = [
        ("command", .command), ("option", .option), ("control", .control), ("shift", .shift),
    ]
}

/// Coded as names, so device profiles stay readable: `["control", "command"]`.
extension Modifiers: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self = []
        for name in try container.decode([String].self) {
            guard let modifier = Self.names.first(where: { $0.0 == name })?.1 else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown modifier \(name)")
            }
            insert(modifier)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(Self.names.filter { contains($0.1) }.map(\.0))
    }
}

public struct KeyCombo: Hashable, Codable, Sendable {
    public var keyCode: UInt16
    public var modifiers: Modifiers
    // Captured at record time so the core never needs keyboard layout APIs.
    public var label: String

    public init(keyCode: UInt16, modifiers: Modifiers, label: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.label = label
    }
}

public struct Keystroke: Hashable, Codable, Sendable {
    public var keyCode: UInt16
    public var modifiers: Modifiers

    public init(keyCode: UInt16, modifiers: Modifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }
}

public enum SystemAction: String, Hashable, Codable, Sendable, CaseIterable {
    case missionControl, appExpose, showDesktop, spaceLeft, spaceRight, navigateBack, navigateForward
    case nextTab, previousTab, toggleFullScreen

    /// The default macOS shortcut for the action, or nil when it is triggered another way.
    public var keystroke: Keystroke? {
        // Virtual key codes from Carbon's Events.h, kept here so the core stays free of Carbon.
        switch self {
        case .missionControl: nil
        case .appExpose: Keystroke(keyCode: 125, modifiers: .control)
        case .showDesktop: Keystroke(keyCode: 103, modifiers: [])
        case .spaceLeft: Keystroke(keyCode: 123, modifiers: .control)
        case .spaceRight: Keystroke(keyCode: 124, modifiers: .control)
        case .navigateBack: Keystroke(keyCode: 33, modifiers: .command)
        case .navigateForward: Keystroke(keyCode: 30, modifiers: .command)
        case .nextTab: Keystroke(keyCode: 48, modifiers: .control)
        case .previousTab: Keystroke(keyCode: 48, modifiers: [.control, .shift])
        case .toggleFullScreen: Keystroke(keyCode: 3, modifiers: [.control, .command])
        }
    }

    /// Names a keystroke a mouse types, so the UI can say "Desktop on the left" rather than "⌃←".
    public init?(_ keystroke: Keystroke) {
        guard let match = Self.allCases.first(where: { $0.keystroke == keystroke }) else { return nil }
        self = match
    }
}

public enum MediaKey: String, Hashable, Codable, Sendable, CaseIterable {
    case playPause, nextTrack, previousTrack, volumeUp, volumeDown, mute
}

public enum Action: Hashable, Codable, Sendable {
    case passthrough
    case disabled
    case mouseButton(number: Int)
    case shortcut(combo: KeyCombo)
    case system(action: SystemAction)
    case media(key: MediaKey)
}
