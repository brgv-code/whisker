import SwiftUI

@main
struct WhiskerApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        Window("Whisker", id: "main") {
            MainView().environment(model)
        }
        .windowResizability(.contentMinSize)

        MenuBarExtra("Whisker", systemImage: "computermouse") {
            MenuContent().environment(model)
        }
    }
}

private struct MenuContent: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Toggle("Enabled", isOn: Binding(get: { model.store.settings.isEnabled }, set: { model.store.setEnabled($0) }))
        Toggle("Open at Login", isOn: Binding(get: { model.opensAtLogin }, set: { model.setOpensAtLogin($0) }))
        Divider()
        Button("Settings…") {
            openWindow(id: "main")
            NSApp.activate()
        }
        .keyboardShortcut(",")
        Button("Quit Whisker") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
