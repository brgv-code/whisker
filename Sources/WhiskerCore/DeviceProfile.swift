public struct DeviceProfile: Hashable, Codable, Sendable, Identifiable {
    public struct Point: Hashable, Codable, Sendable {
        public var x: Double
        public var y: Double
    }

    public struct Button: Hashable, Codable, Sendable {
        public var number: Int
        public var label: String
        public var position: Point
        public var sends: Keystroke?
    }

    public var name: String
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
