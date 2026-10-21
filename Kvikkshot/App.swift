import SwiftUI

@main
struct KvikkshotApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate
    @State private var model = AppModel()

    var body: some Scene {
        Window(Text(verbatim: "Kvikkshot"), id: "main") {
            ContentView(model: model)
                .onAppear { delegate.onOpen = { urls in Task { await model.add(urls) } } }
        }
        .defaultSize(width: 1240, height: 820)
        .windowResizability(.contentMinSize)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Add Videos…", action: model.chooseVideos)
                    .keyboardShortcut("o")
            }
            CommandGroup(after: .newItem) {
                Divider()
                Button("Export Screenshots…", action: model.exportSelected)
                    .keyboardShortcut("e")
                    .disabled(!model.canExport)
                Button("Export All Videos…", action: model.exportAll)
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                    .disabled(!model.canExportAll)
                Button("Create Share Image…") { model.showShareImage = true }
                    .keyboardShortcut("g")
                    .disabled(!model.canExport)
                Divider()
                Button("Remove Video") {
                    if let item = model.selected { model.remove(item) }
                }
                .disabled(model.selected == nil)
            }
            // These open in the browser; the app itself has no network access.
            CommandGroup(replacing: .help) {
                Link("Kvikkshot Website", destination: Links.website)
                Link("Support & Privacy", destination: Links.support)
                Link("Contact Support", destination: Links.contact)
                #if !APPSTORE
                Divider()
                Link("Check for a New Version…", destination: Links.newVersion)
                #endif
            }
        }

        Settings {
            SettingsView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var pending: [URL] = []

    var onOpen: (([URL]) -> Void)? {
        didSet {
            if let onOpen, !pending.isEmpty { onOpen(pending) }
            pending = []
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        if let onOpen { onOpen(urls) } else { pending += urls }
    }

    // Screenshots only ever live in the app's sandboxed temp folder. It is wiped on quit, and again on
    // launch in case the previous run crashed or was force-quit before it could clean up.
    func applicationDidFinishLaunching(_ notification: Notification) {
        try? FileManager.default.removeItem(at: tempRoot)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationWillTerminate(_ notification: Notification) {
        try? FileManager.default.removeItem(at: tempRoot)
    }
}
