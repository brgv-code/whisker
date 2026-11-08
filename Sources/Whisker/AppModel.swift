import AppKit
import Observation
import ServiceManagement
import WhiskerCore

@MainActor @Observable
final class AppModel {
    let runtime = RuntimeState()
    let store: SettingsStore
    let catalog = DeviceCatalog()

    var connected: [ConnectedDevice] = []
    private(set) var selectedDevice: DeviceID?
    private var hasUserPickedDevice = false
    var hasAccessibility = Permissions.hasAccessibility
    var hasInputMonitoring = Permissions.hasInputMonitoring
    var opensAtLogin = SMAppService.mainApp.status == .enabled
    var detectedButtons: [DeviceID: Set<Int>] = [:]
    var lastDetection: (device: DeviceID, button: Int)?
    var isDetecting = false {
        didSet {
            let isDetecting = isDetecting
            runtime.update { $0.isDetecting = isDetecting }
        }
    }

    private var tap: EventTap?
    private var permissionTimer: Timer?

    init() {
        store = SettingsStore(runtime: runtime)
        observeFrontmostApp()
        startWhenPermitted()
    }

    var sidebarDevices: [ConnectedDevice] {
        let connectedIDs = Set(connected.map(\.id))
        let saved = store.settings.devices.map(\.device).filter { !connectedIDs.contains($0) }.map { id in
            ConnectedDevice(id: id, name: catalog.profile(for: id)?.name ?? "Mouse \(id)")
        }
        return connected + saved
    }

    func displayName(for device: ConnectedDevice) -> String {
        catalog.profile(for: device.id)?.name ?? device.name
    }

    func setOpensAtLogin(_ isOn: Bool) {
        do {
            if isOn { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("Whisker: could not change login item: \(error)")
        }
        opensAtLogin = SMAppService.mainApp.status == .enabled
    }

    func requestPermissions() {
        if !hasAccessibility { Permissions.requestAccessibility() }
        if !hasInputMonitoring { Permissions.requestInputMonitoring() }
    }

    private func startWhenPermitted() {
        if startInputIfPossible() { return }
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.startInputIfPossible() else { return }
                self.permissionTimer?.invalidate()
                self.permissionTimer = nil
            }
        }
    }

    private func startInputIfPossible() -> Bool {
        hasAccessibility = Permissions.hasAccessibility
        hasInputMonitoring = Permissions.hasInputMonitoring
        guard hasAccessibility, hasInputMonitoring, tap == nil else { return tap != nil }

        let monitor = DeviceMonitor { [weak self] devices in
            Task { @MainActor in self?.devicesChanged(devices) }
        }
        let tap = EventTap(runtime: runtime, devices: monitor, catalog: catalog) { [weak self] device, button in
            Task { @MainActor in self?.detected(button, on: device) }
        }
        guard tap.start() else { return false }
        self.tap = tap
        return true
    }

    func pick(_ device: DeviceID) {
        hasUserPickedDevice = true
        selectedDevice = device
    }

    private func devicesChanged(_ devices: [ConnectedDevice]) {
        connected = devices
        guard !hasUserPickedDevice else { return }
        let isKnown = { (device: ConnectedDevice) in
            self.catalog.profile(for: device.id) != nil || self.store.settings.settings(for: device.id) != nil
        }
        selectedDevice = (devices.first(where: isKnown) ?? devices.first)?.id
    }

    private func detected(_ button: Int, on device: DeviceID?) {
        isDetecting = false
        guard let device else { return }
        detectedButtons[device, default: []].insert(button)
        selectedDevice = device
        lastDetection = (device, button)
    }

    private func observeFrontmostApp() {
        let runtime = runtime
        let current = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        runtime.update { $0.frontmostApp = current }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { note in
            let app = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier
            runtime.update { $0.frontmostApp = app }
        }
    }
}
