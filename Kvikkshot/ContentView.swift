import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Bindable var model: AppModel
    @AppStorage("mode") private var mode = ExtractMode.count
    @AppStorage("interval") private var interval = 10.0
    @AppStorage("count") private var count = 24
    @AppStorage("precise") private var precise = false
    @AppStorage("format") private var format = ShotFormat.jpg
    @AppStorage("jpegQuality") private var quality = 0.9
    @State private var dropping = false

    private var settings: ExtractSettings {
        ExtractSettings(mode: mode, interval: interval, count: count, precise: precise, format: format, quality: quality)
    }

    var body: some View {
        // A plain sidebar rather than NavigationSplitView: the split view restores a collapsed,
        // too-narrow width whenever it reappears, and the list only shows with two or more videos.
        HStack(spacing: 0) {
            if model.videos.count > 1 {
                VideoList(model: model)
                    .frame(width: 250)
                Divider()
            }
            Group {
                if let item = model.selected {
                    VideoDetail(model: model, item: item)
                } else {
                    DropZone(highlighted: dropping, open: model.chooseVideos)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle(model.selected?.info.url.lastPathComponent ?? "Kvikkshot")
        .navigationSubtitle(model.selected?.info.summary ?? "")
        .toolbar { toolbar }
        .frame(minWidth: 980, minHeight: 620)
        .overlay {
            if dropping && !model.videos.isEmpty {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.accentColor, lineWidth: 3)
                    .padding(3)
                    .allowsHitTesting(false)
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            let videos = urls.filter { !(UTType(filenameExtension: $0.pathExtension)?.conforms(to: .image) ?? false) }
            guard !videos.isEmpty else { return false }
            Task { await model.add(videos) }
            return true
        } isTargeted: { dropping = $0 }
        .task(id: settings) {
            // Short debounce so typing "300" doesn't start three extractions
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            model.apply(settings)
        }
        .sheet(isPresented: $model.showShareImage) {
            if let item = model.selected {
                SheetView(shots: item.selectedShots, video: item.info)
            }
        }
        .alert(model.alert?.title ?? "", isPresented: Binding(get: { model.alert != nil }, set: { if !$0 { model.alert = nil } })) {
            Button("OK") {}
        } message: {
            Text(model.alert?.message ?? "")
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            if !model.videos.isEmpty {
                Button(action: model.closeAll) {
                    Label("Back", systemImage: "chevron.left")
                }
                .keyboardShortcut(.cancelAction)
                .help("Close all videos and go back to the start screen (Esc)")
            }
            Button(action: model.chooseVideos) {
                Label("Add Videos", systemImage: "plus")
            }
            .help("Add Videos")
        }

        ToolbarItem(placement: .primaryAction) {
            CaptureSettingsButton(mode: $mode, interval: $interval, count: $count, precise: $precise, format: $format)
        }
    }
}

private struct VideoList: View {
    @Bindable var model: AppModel

    var body: some View {
        List(selection: $model.selectedID) {
            ForEach(model.videos) { item in
                VideoRow(item: item)
                    .tag(item.id)
                    .contextMenu {
                        Button("Remove") { model.remove(item) }
                    }
            }
        }
        .listStyle(.sidebar)
        .onDeleteCommand {
            if let item = model.selected { model.remove(item) }
        }
        .safeAreaInset(edge: .bottom) {
            if model.videos.count > 1 {
                Button("Export All (\(model.videos.count) videos)", action: model.exportAll)
                    .disabled(!model.canExportAll)
                    .frame(maxWidth: .infinity)
                    .padding(10)
            }
        }
    }
}

private struct VideoRow: View {
    let item: VideoItem

    var body: some View {
        HStack(spacing: 10) {
            ThumbnailView(file: item.shots.first?.thumbFile, aspect: item.info.aspect)
                .frame(width: 64)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            VStack(alignment: .leading, spacing: 2) {
                Text(item.info.url.lastPathComponent)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Group {
                    switch item.status {
                    case .pending:
                        Text("Waiting…")
                    case .extracting:
                        Text(verbatim: "\(item.shots.count) / \(item.total)").monospacedDigit()
                    case .done:
                        Text(verbatim: shotCount(item.shots.count))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct VideoDetail: View {
    @Bindable var model: AppModel
    let item: VideoItem

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 12)], spacing: 12) {
                    ForEach(item.shots) { shot in
                        ShotCell(shot: shot, aspect: item.info.aspect, selected: !item.deselected.contains(shot.id))
                            .onTapGesture { item.toggle(shot.id) }
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
                if item.shots.isEmpty && item.status != .done { ProgressView() }
            }
            Divider()
            footer
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if item.status == .extracting {
                ProgressView(value: Double(item.shots.count), total: Double(max(item.total, 1)))
                    .frame(width: 140)
                Text(verbatim: "\(item.shots.count) / \(item.total)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            } else {
                Text(status).foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                item.toggleAll()
            } label: {
                if item.deselected.isEmpty { Text("Deselect All") } else { Text("Select All") }
            }
            .disabled(item.shots.isEmpty)
            Button("Export \(item.selectedCount)", action: model.exportSelected)
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
        var parts = [shotCount(item.shots.count)]
        if let elapsed = item.elapsed {
            let seconds = elapsed.formatted(.number.precision(.fractionLength(2)))
            parts.append(String(localized: "Took \(seconds) s"))
        }
        if !item.deselected.isEmpty { parts.append(String(localized: "\(item.selectedCount) selected")) }
        if item.failed > 0 { parts.append(String(localized: "\(item.failed) couldn't be read")) }
        return parts.joined(separator: " · ")
    }
}

/// Loads a thumbnail from disk on demand; holds its space at the video's aspect ratio meanwhile.
struct ThumbnailView: View {
    let file: URL?
    let aspect: CGFloat
    @State private var image: NSImage?

    var body: some View {
        Color.secondary.opacity(0.12)
            .aspectRatio(aspect, contentMode: .fit)
            .overlay {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                }
            }
            .clipped()
            .task(id: file) {
                image = nil
                if let file { image = await Thumbnails.image(for: file) }
            }
    }
}

private struct ShotCell: View {
    let shot: Shot
    let aspect: CGFloat
    let selected: Bool

    var body: some View {
        ThumbnailView(file: shot.thumbFile, aspect: aspect)
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
            Text("Drop videos here")
                .font(.title2.weight(.semibold))
            Text("MP4 · MOV · M4V — drop one or several, screenshots start as soon as you let go")
                .foregroundStyle(.secondary)
            Text("Set the interval or count in the toolbar first if you like")
                .font(.callout)
                .foregroundStyle(.tertiary)
            Button("Choose Videos…", action: open)
                .controlSize(.large)
                .padding(.top, 6)
        }
        .multilineTextAlignment(.center)
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                .foregroundStyle(highlighted ? Color.accentColor : Color.secondary.opacity(0.4))
                .padding(24)
        )
    }
}
