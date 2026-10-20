import SwiftUI
import UniformTypeIdentifiers

private struct ExtractKey: Equatable {
    var video: UUID?
    var mode: ExtractMode
    var interval: Double
    var count: Int
    var precise: Bool
    var format: ShotFormat
}

struct ContentView: View {
    @Bindable var model: AppModel
    @AppStorage("mode") private var mode = ExtractMode.count
    @AppStorage("interval") private var interval = 10.0
    @AppStorage("count") private var count = 24
    @AppStorage("precise") private var precise = false
    @AppStorage("format") private var format = ShotFormat.jpg
    @State private var dropping = false

    private var key: ExtractKey {
        ExtractKey(video: model.video?.id, mode: mode, interval: interval, count: count, precise: precise, format: format)
    }

    private var selectedCount: Int { model.shots.count - model.deselected.count }

    var body: some View {
        Group {
            if let video = model.video {
                VStack(spacing: 0) {
                    header(video)
                    Divider()
                    grid
                    Divider()
                    footer
                }
            } else {
                DropZone(highlighted: dropping, open: model.chooseVideo)
            }
        }
        .frame(minWidth: 900, minHeight: 620)
        .overlay {
            if dropping && model.video != nil {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.accentColor, lineWidth: 3)
                    .padding(3)
                    .allowsHitTesting(false)
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first,
                  !(UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) ?? false)
            else { return false }
            Task { await model.open(url) }
            return true
        } isTargeted: { dropping = $0 }
        .task(id: key) {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            model.extract(mode: mode, interval: interval, count: count, precise: precise, format: format)
        }
        .sheet(isPresented: $model.showShareImage) {
            if let video = model.video {
                SheetView(shots: model.selectedShots, video: video)
            }
        }
        .alert(model.alert?.title ?? "", isPresented: Binding(get: { model.alert != nil }, set: { if !$0 { model.alert = nil } })) {
            Button("OK") {}
        } message: {
            Text(model.alert?.message ?? "")
        }
        .navigationTitle(model.video?.url.lastPathComponent ?? "QuickShots")
    }

    private func header(_ video: VideoInfo) -> some View {
        HStack(spacing: 14) {
            Button { model.close() } label: {
                Label("Back", systemImage: "chevron.left")
            }
            .keyboardShortcut(.cancelAction)
            .help("Back to the start screen to choose another video (Esc)")

            VStack(alignment: .leading, spacing: 2) {
                Text(video.url.lastPathComponent)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(video.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)

            Picker(selection: $mode) {
                Text("By Interval").tag(ExtractMode.interval)
                Text("By Count").tag(ExtractMode.count)
            } label: {
                EmptyView()
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()

            HStack(spacing: 4) {
                if mode == .interval {
                    Text("Every")
                    TextField(value: $interval, format: .number) { EmptyView() }
                        .frame(width: 56)
                        .multilineTextAlignment(.trailing)
                    Stepper(value: $interval, in: 0.5...3600, step: 1) { EmptyView() }
                        .labelsHidden()
                    Text("sec")
                } else {
                    Text("Take")
                    TextField(value: $count, format: .number) { EmptyView() }
                        .frame(width: 56)
                        .multilineTextAlignment(.trailing)
                    Stepper(value: $count, in: 1...2000) { EmptyView() }
                        .labelsHidden()
                    Text("shots")
                }
            }

            Toggle("Precise Frames", isOn: $precise)
                .toggleStyle(.checkbox)
                .help("Off: grabs the nearest keyframe — much faster. On: exact to the frame.")

            Picker(selection: $format) {
                Text(verbatim: "JPG").tag(ShotFormat.jpg)
                Text(verbatim: "PNG").tag(ShotFormat.png)
            } label: {
                EmptyView()
            }
            .labelsHidden()
            .fixedSize()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 12)], spacing: 12) {
                ForEach(model.shots) { shot in
                    ShotCell(shot: shot, selected: !model.deselected.contains(shot.id))
                        .onTapGesture { model.toggle(shot.id) }
                        .onDrag { NSItemProvider(contentsOf: shot.file) ?? NSItemProvider() }
                        .contextMenu {
                            Button("Open in Preview") { NSWorkspace.shared.open(shot.file) }
                            Button("Copy Image") {
                                if let image = NSImage(contentsOf: shot.file) {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.writeObjects([image])
                                }
                            }
                        }
                }
            }
            .padding(16)
        }
        .overlay {
            if model.shots.isEmpty && model.isExtracting { ProgressView() }
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if model.isExtracting {
                ProgressView(value: Double(model.shots.count), total: Double(max(model.total, 1)))
                    .frame(width: 140)
                Text(verbatim: "\(model.shots.count) / \(model.total)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            } else {
                Text(status).foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                model.toggleAll()
            } label: {
                if model.deselected.isEmpty { Text("Deselect All") } else { Text("Select All") }
            }
            .disabled(model.shots.isEmpty)
            Button("Open…", action: model.chooseVideo)
            Button("Export \(selectedCount)", action: model.export)
                .disabled(!model.canExport)
            Button("Create Share Image") { model.showShareImage = true }
                .buttonStyle(.borderedProminent)
                .disabled(!model.canExport)
        }
        .font(.callout)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var status: String {
        var parts = [shotCount(model.shots.count)]
        if let elapsed = model.elapsed {
            let seconds = elapsed.formatted(.number.precision(.fractionLength(2)))
            parts.append(String(localized: "Took \(seconds) s"))
        }
        if !model.deselected.isEmpty { parts.append(String(localized: "\(selectedCount) selected")) }
        if model.failed > 0 { parts.append(String(localized: "\(model.failed) couldn't be read")) }
        return parts.joined(separator: " · ")
    }
}

private struct ShotCell: View {
    let shot: Shot
    let selected: Bool

    var body: some View {
        Image(nsImage: shot.thumb)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .overlay(alignment: .bottomTrailing) {
                Text(verbatim: formatTime(shot.time))
                    .font(.caption.monospacedDigit().weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 4))
                    .padding(6)
            }
            .overlay(alignment: .topLeading) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, selected ? Color.accentColor : .black.opacity(0.3))
                    .shadow(radius: 2)
                    .padding(6)
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(selected ? Color.accentColor : .clear, lineWidth: 2))
            .opacity(selected ? 1 : 0.35)
            .contentShape(Rectangle())
    }
}

private struct DropZone: View {
    let highlighted: Bool
    let open: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "film.stack")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(highlighted ? Color.accentColor : .secondary)
            Text("Drop a video here")
                .font(.title2.weight(.semibold))
            Text("MP4 · MOV · M4V — screenshots start as soon as you let go")
                .foregroundStyle(.secondary)
            Button("Choose Video…", action: open)
                .controlSize(.large)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                .foregroundStyle(highlighted ? Color.accentColor : Color.secondary.opacity(0.4))
                .padding(24)
        )
    }
}
