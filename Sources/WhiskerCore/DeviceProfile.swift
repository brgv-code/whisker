/// A shareable description of one mouse model: which buttons it has and where they sit on the diagram.
public struct DeviceProfile: Hashable, Codable, Sendable, Identifiable {
    public struct Point: Hashable, Codable, Sendable {
        /// Both axes run 0...1 across the diagram, origin top left.
        public var x: Double
        public var y: Double
    }

    public struct Button: Hashable, Codable, Sendable {
        /// macOS button number: 1 right, 2 middle, 3 back, 4 forward, 5 and up extra.
        public var number: Int
        public var label: String
        public var position: Point
        /// Set when the firmware types a shortcut for this button. Default lets it through; other actions replace it.
        public var sends: Keystroke?
    }

    public var name: String
    /// A model can ship several receivers or a Bluetooth mode, each with its own ID.
    public var devices: [DeviceID]
    public var buttons: [Button]
    public var thumbWheel: Point?

    public var id: String { name }

    public var hasKeyButtons: Bool { buttons.contains { $0.sends != nil } }

    public func button(sending keyCode: UInt16, modifiers: Modifiers) -> Int? {
        let trigger = Keystroke(keyCode: keyCode, modifiers: modifiers)
        return buttons.first { $0.sends == trigger }?.number
    }
}
