import SwiftUI

@main
struct QuickShotsApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate
    @State private var model = AppModel()

    var body: some Scene {
        Window(Text(verbatim: "QuickShots"), id: "main") {
            ContentView(model: model)
                .onAppear { delegate.onOpen = { url in Task { await model.open(url) } } }
        }
        .defaultSize(width: 1200, height: 800)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Video…") { model.chooseVideo() }
                    .keyboardShortcut("o")
            }
            CommandGroup(after: .newItem) {
                Divider()
                Button("Export Screenshots…") { model.export() }
                    .keyboardShortcut("e")
                    .disabled(!model.canExport)
                Button("Create Share Image…") { model.showShareImage = true }
                    .keyboardShortcut("g")
                    .disabled(!model.canExport)
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var pending: [URL] = []

    var onOpen: ((URL) -> Void)? {
        didSet {
            if let onOpen, let url = pending.last { onOpen(url) }
            pending = []
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        if let onOpen { onOpen(url) } else { pending.append(url) }
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
