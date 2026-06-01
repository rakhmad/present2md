import SwiftUI
import UniformTypeIdentifiers

struct FileListView: View {
    @EnvironmentObject var coordinator: ConversionCoordinator

    var body: some View {
        List(coordinator.jobs) { job in
            FileRowView(job: job)
        }
        .listStyle(.plain)
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers: providers)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var urls: [URL] = []
        let group = DispatchGroup()
        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                defer { group.leave() }
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                let ext = url.pathExtension.lowercased()
                if ["pdf", "pptx", "ods"].contains(ext) { urls.append(url) }
            }
        }
        group.notify(queue: .main) {
            if !urls.isEmpty { coordinator.addJobs(urls: urls) }
        }
        return true
    }
}
