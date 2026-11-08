import Foundation
import Observation
import WhiskerCore

@MainActor @Observable
final class SettingsStore {
    private(set) var settings: Settings
    private let runtime: RuntimeState
    private let fileURL: URL

    init(runtime: RuntimeState) {
        let folder = URL.applicationSupportDirectory.appending(path: "Whisker")
        self.fileURL = folder.appending(path: "settings.json")
        self.runtime = runtime
        self.settings = Self.load(from: fileURL)
        publish()
    }

    func setEnabled(_ isEnabled: Bool) {
        settings.isEnabled = isEnabled
        save()
    }

    func deviceSettings(for device: DeviceID) -> DeviceSettings {
        settings.settings(for: device) ?? DeviceSettings(device: device)
    }

    func update(_ device: DeviceID, _ change: (inout DeviceSettings) -> Void) {
        var deviceSettings = deviceSettings(for: device)
        change(&deviceSettings)
        settings.devices.removeAll { $0.device == device }
        settings.devices.append(deviceSettings)
        save()
    }

    private func save() {
        publish()
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(settings).write(to: fileURL, options: .atomic)
        } catch {
            NSLog("Whisker: could not save settings: \(error)")
        }
    }

    private func publish() {
        let settings = settings
        runtime.update { $0.settings = settings }
    }

    private static func load(from url: URL) -> Settings {
        guard let contents = try? Data(contentsOf: url) else { return Settings() }
        do {
            return try JSONDecoder().decode(Settings.self, from: contents)
        } catch {
            // Keep the unreadable file for the user instead of silently overwriting it.
            let backup = url.deletingPathExtension().appendingPathExtension("broken.json")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.moveItem(at: url, to: backup)
            NSLog("Whisker: settings unreadable (\(error)), moved to \(backup.path)")
            return Settings()
        }
    }
}
