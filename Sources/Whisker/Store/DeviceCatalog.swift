import Foundation
import WhiskerCore

struct DeviceCatalog {
    let profiles: [DeviceProfile]

    init(bundle: Bundle = .main) {
        let folder = bundle.resourceURL?.appending(path: "Devices")
        let files =
            folder.flatMap { try? FileManager.default.contentsOfDirectory(at: $0, includingPropertiesForKeys: nil) }
            ?? []
        profiles = files.filter { $0.pathExtension == "json" }.compactMap { file in
            do {
                return try JSONDecoder().decode(DeviceProfile.self, from: Data(contentsOf: file))
            } catch {
                NSLog("Whisker: skipping device profile \(file.lastPathComponent): \(error)")
                return nil
            }
        }
    }

    func profile(for device: DeviceID) -> DeviceProfile? {
        profiles.first { $0.devices.contains(device) }
    }
}
