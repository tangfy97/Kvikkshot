import SwiftUI

struct SettingsView: View {
    @AppStorage(ExportFolder.key) private var exportBookmark: Data?
    @AppStorage("jpegQuality") private var quality = 0.9
    @AppStorage("shareBadge") private var shareBadge = true

    var body: some View {
        Form {
            Section("Export") {
                LabeledContent("Default folder") {
                    HStack {
                        if let folder = ExportFolder.resolve(exportBookmark) {
                            Text(folder.path(percentEncoded: false))
                                .lineLimit(1)
                                .truncationMode(.head)
                                .help(folder.path(percentEncoded: false))
                        } else {
                            Text("Ask every time").foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Choose…", action: chooseFolder)
                        if exportBookmark != nil {
                            Button("Ask Every Time") { exportBookmark = nil }
                        }
                    }
                }
                Text("When a default folder is set, Export saves straight into it without asking.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                LabeledContent("JPEG quality") {
                    HStack {
                        Slider(value: $quality, in: 0.5...1, step: 0.05)
                        Text(verbatim: quality.formatted(.percent.precision(.fractionLength(0))))
                            .monospacedDigit()
                            .frame(width: 44, alignment: .trailing)
                    }
                }
            }

            Section("Share Image") {
                Toggle("Add “Made with Kvikkshot” to share images", isOn: $shareBadge)
            }

            Section("Privacy") {
                Text("Kvikkshot works entirely on this Mac and never connects to the internet. Screenshots are kept in a private temporary folder and deleted when you go back or quit — only what you export or save is kept.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = String(localized: "Use This Folder")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        exportBookmark = ExportFolder.bookmark(for: url)
    }
}
