import SwiftUI

/// One toolbar button that summarises the capture settings and opens them in a popover.
struct CaptureSettingsButton: View {
    @Binding var mode: ExtractMode
    @Binding var interval: Double
    @Binding var count: Int
    @Binding var precise: Bool
    @Binding var format: ShotFormat
    @State private var showing = false

    private var summary: String {
        var parts = [mode == .interval
            ? String(localized: "Every \(interval.formatted()) sec")
            : shotCount(count)]
        if precise { parts.append(String(localized: "Precise")) }
        if format == .png { parts.append("PNG") }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        Button {
            showing.toggle()
        } label: {
            Label(summary, systemImage: "slider.horizontal.3")
                .labelStyle(.titleAndIcon)
        }
        .help("Screenshot Settings")
        .popover(isPresented: $showing, arrowEdge: .bottom) {
            Form {
                Picker("Capture", selection: $mode) {
                    Text("By Interval").tag(ExtractMode.interval)
                    Text("By Count").tag(ExtractMode.count)
                }
                .pickerStyle(.segmented)

                if mode == .interval {
                    LabeledContent("Every") {
                        HStack(spacing: 6) {
                            TextField(value: $interval, format: .number) { EmptyView() }
                                .frame(width: 64)
                                .multilineTextAlignment(.trailing)
                            Stepper(value: $interval, in: 0.5...3600, step: 1) { EmptyView() }
                                .labelsHidden()
                            Text("sec")
                        }
                    }
                } else {
                    LabeledContent("Number of shots") {
                        HStack(spacing: 6) {
                            TextField(value: $count, format: .number) { EmptyView() }
                                .frame(width: 64)
                                .multilineTextAlignment(.trailing)
                            Stepper(value: $count, in: 1...2000) { EmptyView() }
                                .labelsHidden()
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Precise Frames", isOn: $precise)
                    Text("Off: grabs the nearest keyframe — much faster. On: exact to the frame.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Picker("Format", selection: $format) {
                    Text(verbatim: "JPG").tag(ShotFormat.jpg)
                    Text(verbatim: "PNG").tag(ShotFormat.png)
                }
                .pickerStyle(.segmented)
            }
            .formStyle(.grouped)
            .frame(width: 360)
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}
