import SwiftUI

struct MainView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        NavigationSplitView {
            List(model.sidebarDevices, selection: $model.selectedDevice) { device in
                VStack(alignment: .leading) {
                    Text(model.displayName(for: device))
                    Text(model.connected.contains(device) ? device.id.description : "Not connected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .tag(device.id)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 210)
        } detail: {
            VStack(spacing: 0) {
                if !model.hasAccessibility || !model.hasInputMonitoring {
                    PermissionBanner()
                }
                if let device = model.sidebarDevices.first(where: { $0.id == model.selectedDevice }) {
                    DeviceView(device: device).id(device.id)
                } else {
                    ContentUnavailableView(
                        "No mouse selected", systemImage: "computermouse",
                        description: Text("Connect a mouse, then pick it from the list."))
                }
            }
        }
        .frame(minWidth: 860, minHeight: 600)
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
        .padding()
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
