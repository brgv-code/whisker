import AppKit
import SwiftUI
import WhiskerCore

enum Control: Hashable {
    case button(Int)
    case thumbWheel
}

struct ControlRow: Identifiable, Hashable {
    var number: Int
    var label: String
    var position: DeviceProfile.Point?
    var id: Int { number }
}

struct DeviceView: View {
    let device: ConnectedDevice
    @Environment(AppModel.self) private var model
    @State private var selected: Control?
    /// Bundle identifier of the app being edited; nil edits the setup for all apps.
    @State private var scope: String?

    private var profile: DeviceProfile? { model.catalog.profile(for: device.id) }
    private var settings: DeviceSettings { model.store.deviceSettings(for: device.id) }

    private var rows: [ControlRow] {
        var rows = (profile?.buttons ?? []).map {
            ControlRow(number: $0.number, label: $0.label, position: $0.position)
        }
        let listed = Set(rows.map(\.number))
        let configured = Set(settings.buttons.keys).union(settings.appOverrides.values.flatMap(\.keys))
        let extra = configured.union(model.detectedButtons[device.id] ?? []).subtracting(listed).subtracting([0])
        rows += extra.sorted().map { ControlRow(number: $0, label: "Button \($0 + 1)", position: nil) }
        return rows
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(spacing: 16) {
                MouseDiagram(rows: rows, thumbWheel: profile?.thumbWheel, selected: $selected)
                Button(model.isDetecting ? "Press a mouse button…" : "Detect Button") {
                    model.isDetecting.toggle()
                }
                .disabled(!model.hasAccessibility)
                Text("Press a button on the mouse to find it in the list.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 260)
            .padding()

            Form {
                Section("Controls") {
                    ForEach(Array(rows.enumerated()), id: \.element) { index, row in
                        controlButton(
                            index: index + 1, title: row.label, control: .button(row.number),
                            summary: summary(for: row.number))
                    }
                    if profile?.thumbWheel != nil {
                        controlButton(
                            index: rows.count + 1, title: "Thumb wheel", control: .thumbWheel,
                            summary: settings.thumbWheel == .scroll ? "Scroll sideways" : "Actions")
                    }
                }
                editor
                ScrollSection(device: device.id, isAppScope: scope != nil)
            }
            .formStyle(.grouped)
        }
        .navigationTitle(model.displayName(for: device))
        .toolbar { ScopePicker(device: device.id, scope: $scope) }
        .onChange(of: model.lastDetection?.button) {
            if let detection = model.lastDetection, detection.device == device.id {
                selected = .button(detection.button)
            }
        }
    }

    @ViewBuilder private var editor: some View {
        switch selected {
        case .button(let number):
            Section(rows.first { $0.number == number }?.label ?? "Button \(number + 1)") {
                ButtonEditor(device: device.id, button: number, scope: scope)
            }
        case .thumbWheel:
            Section("Thumb wheel") { ThumbWheelEditor(device: device.id) }
        case nil:
            Section {
                Text("Select a control on the mouse or in the list above.").foregroundStyle(.secondary)
            }
        }
    }

    private func summary(for button: Int) -> String {
        switch settings.binding(for: button, app: scope) {
        case .action(let action): action.title
        case .gesture: "Gesture button"
        }
    }

    private func controlButton(index: Int, title: String, control: Control, summary: String) -> some View {
        Button {
            selected = control
        } label: {
            HStack {
                Text("\(index)").monospacedDigit().foregroundStyle(.secondary).frame(width: 18)
                Text(title)
                Spacer()
                Text(summary).foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(selected == control ? Color.accentColor.opacity(0.15) : nil)
    }
}

private struct ScopePicker: View {
    let device: DeviceID
    @Binding var scope: String?
    @Environment(AppModel.self) private var model

    var body: some View {
        let overrides = model.store.deviceSettings(for: device).appOverrides.keys.sorted()
        Picker("Applies to", selection: $scope) {
            Text("All Apps").tag(String?.none)
            ForEach(overrides, id: \.self) { bundleID in
                Text(Self.appName(bundleID)).tag(Optional(bundleID))
            }
        }
        Menu("Add App", systemImage: "plus") {
            ForEach(Self.runningApps(), id: \.self) { bundleID in
                Button(Self.appName(bundleID)) { add(bundleID) }
            }
            Divider()
            Button("Choose…") { chooseApp() }
        }
        if let scope {
            Button("Remove App", systemImage: "minus") {
                model.store.update(device) { $0.appOverrides.removeValue(forKey: scope) }
                self.scope = nil
            }
        }
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

    static func appName(_ bundleID: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return bundleID }
        return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }
}
