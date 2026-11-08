import SwiftUI

@main
struct WhiskerApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @State private var model = AppModel()

    var body: some Scene {
        Window("Whisker", id: "main") {
            MainView().environment(model).background(WindowOpenerRegistration())
        }
        .windowResizability(.contentMinSize)
        .windowStyle(.hiddenTitleBar)
        .defaultLaunchBehavior(.presented)

        MenuBarExtra("Whisker", systemImage: "computermouse") {
            MenuContent().environment(model)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static var openMainWindow: OpenWindowAction?

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        Self.openMainWindow?(id: "main")
        Self.bringToFront()
        return false
    }

    static func bringToFront() {
        NSApp.activate()
        DispatchQueue.main.async {
            for window in NSApp.windows where window.canBecomeMain {
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
            }
        }
    }
}

private struct WindowOpenerRegistration: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Color.clear.onAppear {
            AppDelegate.openMainWindow = openWindow
            AppDelegate.bringToFront()
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
