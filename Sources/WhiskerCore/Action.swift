public struct Modifiers: OptionSet, Hashable, Codable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let command = Modifiers(rawValue: 1 << 0)
    public static let option = Modifiers(rawValue: 1 << 1)
    public static let control = Modifiers(rawValue: 1 << 2)
    public static let shift = Modifiers(rawValue: 1 << 3)
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

public enum SystemAction: String, Hashable, Codable, Sendable, CaseIterable {
    case missionControl, appExpose, showDesktop, spaceLeft, spaceRight, navigateBack, navigateForward
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
