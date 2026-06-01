import SwiftUI
import AppKit
import present2mdCore

struct FileRowView: View {
    let job: ConversionJob

    var body: some View {
        HStack(spacing: 12) {
            fileIcon
            Text(job.sourceURL.lastPathComponent)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            statusView
        }
        .padding(.vertical, 4)
    }

    private var fileIcon: some View {
        Image(systemName: iconName)
            .foregroundStyle(.secondary)
            .frame(width: 20)
    }

    private var iconName: String {
        switch job.sourceURL.pathExtension.lowercased() {
        case "pdf":  return "doc.richtext"
        case "pptx": return "rectangle.on.rectangle"
        case "ods":  return "tablecells"
        default:     return "doc"
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch job.status {
        case .pending:
            Text("Pending")
                .foregroundStyle(.secondary)
                .font(.caption)
        case .converting:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Converting…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .done:
            HStack(spacing: 8) {
                Label("Done", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
                Button("Reveal") {
                    if let url = job.outputURL {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
        case .failed:
            Label("Failed", systemImage: "xmark.circle.fill")
                .foregroundStyle(.red)
                .font(.caption)
                .help(job.errorMessage ?? "Unknown error")
        }
    }
}
