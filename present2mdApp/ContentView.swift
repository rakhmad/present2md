import SwiftUI
import AppKit
import present2mdCore

struct ContentView: View {
    @EnvironmentObject var coordinator: ConversionCoordinator

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            if coordinator.jobs.isEmpty {
                EmptyStateView()
            } else {
                FileListView()
            }
            Divider()
            footer
        }
        .sheet(isPresented: Binding(
            get: { coordinator.timeoutJobID != nil },
            set: { _ in }
        )) {
            if let jobID = coordinator.timeoutJobID {
                TimeoutAlertView(jobID: jobID)
                    .environmentObject(coordinator)
            }
        }
    }

    private var toolbar: some View {
        HStack {
            Text("present2md")
                .font(.headline)
            Spacer()
            Button("Browse…") { openFiles() }
                .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var footer: some View {
        HStack {
            Button("Clear Completed") { coordinator.clearCompleted() }
                .disabled(coordinator.jobs.filter { $0.status == .done || $0.status == .failed }.isEmpty)
            Spacer()
            let done = coordinator.jobs.filter { $0.status == .done }.count
            let total = coordinator.jobs.count
            if total > 0 {
                Text("\(done)/\(total) done")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func openFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [
            .pdf,
            .init(filenameExtension: "pptx")!,
            .init(filenameExtension: "ods")!
        ]
        panel.begin { response in
            guard response == .OK else { return }
            coordinator.addJobs(urls: panel.urls)
        }
    }
}
