import Foundation
import Testing
import WhiskerCore

@Suite struct Coding {
    @Test func deviceIDCodesAsHexPair() throws {
        let id = DeviceID(vendorID: 0x1ea7, productID: 0x0067)
        let json = try JSONEncoder().encode([id])
        #expect(String(decoding: json, as: UTF8.self) == #"["1ea7:0067"]"#)
        #expect(try JSONDecoder().decode([DeviceID].self, from: json) == [id])
    }

    @Test func malformedDeviceIDIsRejected() {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode([DeviceID].self, from: Data(#"["1ea7"]"#.utf8))
        }
    }

    @Test func modifiersCodeAsNames() throws {
        let json = try JSONEncoder().encode(Modifiers([.control, .command]))
        #expect(String(decoding: json, as: UTF8.self) == #"["command","control"]"#)
        #expect(try JSONDecoder().decode(Modifiers.self, from: Data(#"["shift"]"#.utf8)) == .shift)
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(Modifiers.self, from: Data(#"["hyper"]"#.utf8)) }
    }

    @Test func profileFindsButtonByKeystroke() throws {
        let json = #"""
            {"name": "Test", "devices": ["0001:0002"], "buttons": [
              {"number": 3, "label": "Back", "position": {"x": 0, "y": 0}, "sends": {"keyCode": 123, "modifiers": ["control"]}}
            ]}
            """#
        let profile = try JSONDecoder().decode(DeviceProfile.self, from: Data(json.utf8))
        #expect(profile.button(sending: 123, modifiers: .control) == 3)
        #expect(profile.button(sending: 123, modifiers: []) == nil)
        #expect(profile.hasKeyButtons)
    }

    @Test func settingsRoundTrip() throws {
        var device = DeviceSettings(device: DeviceID(vendorID: 1, productID: 2))
        device.buttons = [
            3: .gesture(.standard),
            4: .action(.shortcut(combo: KeyCombo(keyCode: 8, modifiers: [.command, .shift], label: "⇧⌘C"))),
        ]
        device.thumbWheel = .actions(left: .media(key: .previousTrack), right: .media(key: .nextTrack))
        device.appOverrides = [
            "com.apple.Safari": [3: .action(.disabled), 4: .tapOrHold(tap: .passthrough, hold: .disabled)]
        ]
        let settings = Settings(isEnabled: false, devices: [device])

        let decoded = try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(settings))
        #expect(decoded == settings)
    }

    @Test func bundledDeviceProfilesAreValid() throws {
        let folder = URL(filePath: #filePath).deletingLastPathComponent().appending(path: "../../devices").standardized
        let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
        #expect(!files.isEmpty)

        for file in files {
            let profile = try JSONDecoder().decode(DeviceProfile.self, from: Data(contentsOf: file))
            let numbers = profile.buttons.map(\.number)
            #expect(Set(numbers).count == numbers.count, "\(file.lastPathComponent) lists a button twice")
            #expect(!numbers.contains(0), "\(file.lastPathComponent) remaps the left button, which can lock users out")
            #expect(!profile.devices.isEmpty, "\(file.lastPathComponent) matches no device")
            let triggers = profile.buttons.compactMap(\.sends)
            #expect(
                Set(triggers).count == triggers.count, "\(file.lastPathComponent) maps one keystroke to two buttons")
        }
    }
}
