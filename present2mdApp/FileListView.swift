import SwiftUI
import present2mdCore

struct FileListView: View {
    @EnvironmentObject var coordinator: ConversionCoordinator

    var body: some View {
        List(coordinator.jobs) { job in
            FileRowView(job: job)
        }
        .listStyle(.plain)
        .dropDestination(for: URL.self) { urls, _ in
            let filtered = urls.filter {
                ["pdf", "pptx", "ods"].contains($0.pathExtension.lowercased())
            }
            if !filtered.isEmpty { coordinator.addJobs(urls: filtered) }
            return !filtered.isEmpty
        }
    }
}
