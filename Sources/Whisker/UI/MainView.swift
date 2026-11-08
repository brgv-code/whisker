import AppKit
import SwiftUI
import WhiskerCore

struct MainView: View {
    @Environment(AppModel.self) private var model
    @State private var selected: Control?
    @State private var scope: String?
    @State private var tab = Tab.buttons

    private enum Tab { case buttons, scrolling }

    private var device: ConnectedDevice? { model.sidebarDevices.first { $0.id == model.selectedDevice } }

    var body: some View {
        VStack(spacing: 0) {
            if let device {
                Header(device: device, scope: $scope)
                if !model.hasAccessibility || !model.hasInputMonitoring { PermissionBanner() }
                Picker("Section", selection: $tab) {
                    Text("Buttons").tag(Tab.buttons)
                    Text("Scrolling").tag(Tab.scrolling)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                .padding(.bottom, 12)
                Divider()
                switch tab {
                case .buttons: ButtonsPane(device: device.id, selected: $selected, scope: scope)
                case .scrolling: ScrollPane(device: device.id, isAppScope: scope != nil)
                }
            } else {
                if !model.hasAccessibility || !model.hasInputMonitoring { PermissionBanner().padding(.top, 48) }
                ContentUnavailableView(
                    "No mouse selected", systemImage: "computermouse",
                    description: Text("Connect a mouse, then pick it from the list."))
            }
        }
        .ignoresSafeArea(.container, edges: .top)
        .frame(minWidth: 1000, minHeight: 640)
        .background(
            LinearGradient(
                colors: [Color(nsColor: .windowBackgroundColor), Color(nsColor: .underPageBackgroundColor)],
                startPoint: .top, endPoint: .bottom)
        )
        .onChange(of: model.selectedDevice) {
            selected = nil
            scope = nil
        }
        .onChange(of: model.lastDetection?.button) {
            if let detection = model.lastDetection, detection.device == model.selectedDevice {
                tab = .buttons
                selected = .button(detection.button)
            }
        }
    }
}

private struct ButtonsPane: View {
    let device: DeviceID
    @Binding var selected: Control?
    let scope: String?
    @Environment(AppModel.self) private var model

    private var rows: [ControlRow] {
        let profile = model.catalog.profile(for: device)
        let settings = model.store.deviceSettings(for: device)
        func row(_ number: Int, _ label: String, _ position: DeviceProfile.Point?) -> ControlRow {
            let defaultTitle = Action.defaultTitle(button: number, profile: profile)
            return ControlRow(
                control: .button(number), label: label,
                summary: settings.binding(for: number, app: scope).summary(default: defaultTitle),
                defaultTitle: defaultTitle, position: position)
        }
        var rows = (profile?.buttons ?? []).map { row($0.number, $0.label, $0.position) }
        let listed = Set(profile?.buttons.map(\.number) ?? [])
        let configured = Set(settings.buttons.keys).union(settings.appOverrides.values.flatMap(\.keys))
        let extra = configured.union(model.detectedButtons[device] ?? []).subtracting(listed).subtracting([0])
        rows += extra.sorted().map { row($0, "Button \($0 + 1)", nil) }
        if let thumbWheel = profile?.thumbWheel {
            let summary = settings.thumbWheel == .scroll ? "Scroll sideways" : "Run actions"
            rows.append(ControlRow(control: .thumbWheel, label: "Thumb wheel", summary: summary, position: thumbWheel))
        }
        return rows
    }

    var body: some View {
        let rows = rows
        HStack(spacing: 0) {
            VStack(spacing: 14) {
                DeviceCanvas(rows: rows, selected: $selected)
                let unplaced = rows.filter { $0.position == nil }
                if !unplaced.isEmpty {
                    HStack {
                        ForEach(unplaced) { row in
                            Button("\(row.label): \(row.summary)") { selected = row.control }
                                .buttonStyle(.bordered)
                                .tint(selected == row.control ? .accentColor : nil)
                        }
                    }
                }
                VStack(spacing: 4) {
                    Button(model.isDetecting ? "Press a mouse button…" : "Detect Button") {
                        model.isDetecting.toggle()
                    }
                    .controlSize(.large)
                    .disabled(!model.hasAccessibility)
                    Text("Press a button on the mouse to select it.").font(.caption).foregroundStyle(.secondary)
                }
                .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 20)
            Divider()
            Inspector(device: device, row: rows.first { $0.control == selected }, scope: scope)
        }
    }
}

private struct Header: View {
    let device: ConnectedDevice
    @Binding var scope: String?
    @Environment(AppModel.self) private var model

    var body: some View {
        let isConnected = model.connected.contains(device)
        HStack(spacing: 16) {
            Menu {
                ForEach(model.sidebarDevices) { candidate in
                    Button(model.displayName(for: candidate)) { model.pick(candidate.id) }
                }
            } label: {
                Label(model.displayName(for: device), systemImage: "computermouse.fill").font(.title2.weight(.semibold))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(model.sidebarDevices.count > 1 ? .visible : .hidden)
            .fixedSize()
            HStack(spacing: 5) {
                Circle().fill(isConnected ? Color.green : Color.secondary).frame(width: 7, height: 7)
                Text("\(isConnected ? "Connected" : "Not connected") · \(device.id.description)").font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            AppChips(device: device.id, scope: $scope)
            Toggle(
                "Enabled",
                isOn: Binding(get: { model.store.settings.isEnabled }, set: { model.store.setEnabled($0) })
            )
            .toggleStyle(.switch)
        }
        .padding(.leading, 84)
        .padding(.trailing, 24)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }
}

private struct AppChips: View {
    let device: DeviceID
    @Binding var scope: String?
    @Environment(AppModel.self) private var model

    var body: some View {
        let overrides = model.store.deviceSettings(for: device).appOverrides.keys.sorted {
            Self.appName($0) < Self.appName($1)
        }
        HStack(spacing: 6) {
            chip(title: "All Apps", icon: nil, isSelected: scope == nil) { scope = nil }
            ForEach(overrides, id: \.self) { bundleID in
                chip(title: Self.appName(bundleID), icon: Self.appIcon(bundleID), isSelected: scope == bundleID) {
                    scope = bundleID
                }
                .contextMenu {
                    Button("Remove App") {
                        model.store.update(device) { $0.appOverrides.removeValue(forKey: bundleID) }
                        if scope == bundleID { scope = nil }
                    }
                }
            }
            Menu {
                ForEach(Self.runningApps(), id: \.self) { bundleID in
                    Button(Self.appName(bundleID)) { add(bundleID) }
                }
                Divider()
                Button("Choose…") { chooseApp() }
            } label: {
                Image(systemName: "plus")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Add App")
        }
    }

    private func chip(title: String, icon: NSImage?, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let icon { Image(nsImage: icon).resizable().frame(width: 16, height: 16) }
                Text(title)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .background(Capsule().fill(isSelected ? Color.accentColor : Color.primary.opacity(0.07)))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func add(_ bundleID: String) {
        model.store.update(device) { settings in
            if settings.appOverrides[bundleID] == nil { settings.appOverrides[bundleID] = [:] }
        }
        scope = bundleID
    }

    private func chooseApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(filePath: "/Applications")
        guard panel.runModal() == .OK, let url = panel.url, let bundleID = Bundle(url: url)?.bundleIdentifier else {
            return
        }
        add(bundleID)
    }

    private static func runningApps() -> [String] {
        let apps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
        return Array(Set(apps.compactMap(\.bundleIdentifier))).sorted { appName($0) < appName($1) }
    }

    private static func appName(_ bundleID: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return bundleID }
        return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }

    private static func appIcon(_ bundleID: String) -> NSImage? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID).map {
            NSWorkspace.shared.icon(forFile: $0.path)
        }
    }
}

private struct PermissionBanner: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Text("Whisker needs two permissions to customize your mouse").font(.headline)
                row(
                    "Accessibility", detail: "Lets Whisker change what your buttons and wheels do.",
                    isGranted: model.hasAccessibility, anchor: "Privacy_Accessibility")
                row(
                    "Input Monitoring", detail: "Lets Whisker tell your mice apart.",
                    isGranted: model.hasInputMonitoring, anchor: "Privacy_ListenEvent")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
    }

    private func row(_ title: String, detail: String, isGranted: Bool, anchor: String) -> some View {
        HStack {
            Image(systemName: isGranted ? "checkmark.circle.fill" : "exclamationmark.circle")
                .foregroundStyle(isGranted ? .green : .orange)
            VStack(alignment: .leading) {
                Text(title)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if !isGranted {
                Button("Grant…") {
                    model.requestPermissions()
                    Permissions.openSettings(anchor: anchor)
                }
            }
        }
    }
}
