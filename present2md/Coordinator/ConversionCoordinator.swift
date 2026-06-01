import Foundation
import Combine

@MainActor
public final class ConversionCoordinator: ObservableObject {
    @Published public var jobs: [ConversionJob] = []
    @Published public var timeoutJobID: UUID? = nil

    private let timeoutSeconds: Double

    public init(timeoutSeconds: Double = 60) {
        self.timeoutSeconds = timeoutSeconds
    }

    public func addJobs(urls: [URL]) {
        let newJobs = urls.map { ConversionJob(sourceURL: $0) }
        jobs.append(contentsOf: newJobs)
        for job in newJobs {
            Task.detached(priority: .userInitiated) { [weak self] in
                await self?.run(jobID: job.id)
            }
        }
    }

    public func clearCompleted() {
        jobs.removeAll { $0.status == .done || $0.status == .failed }
    }

    public func continueJob(id: UUID) {
        timeoutJobID = nil
    }

    public func cancelJob(id: UUID) {
        timeoutJobID = nil
        updateJob(id: id, status: .failed, errorMessage: "Cancelled by user.")
    }

    private func run(jobID: UUID) async {
        updateJob(id: jobID, status: .converting)

        guard let job = jobs.first(where: { $0.id == jobID }) else { return }
        guard let converter = ConverterFactory.converter(for: job.sourceURL) else {
            updateJob(id: jobID, status: .failed, errorMessage: "Unsupported file type.")
            return
        }

        let watchdog = Task { [weak self, timeoutSeconds] in
            try await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
            guard let self else { return }
            await MainActor.run {
                self.timeoutJobID = jobID
            }
            while await MainActor.run(body: { self.timeoutJobID == jobID }) {
                try await Task.sleep(nanoseconds: 500_000_000)
            }
        }

        let slides: [Slide]
        do {
            slides = try await Task.detached(priority: .userInitiated) {
                try converter.convert(url: job.sourceURL)
            }.value
        } catch let error as ConverterError {
            watchdog.cancel()
            updateJob(id: jobID, status: .failed, errorMessage: error.errorDescription)
            return
        } catch {
            watchdog.cancel()
            updateJob(id: jobID, status: .failed, errorMessage: error.localizedDescription)
            return
        }

        watchdog.cancel()

        // Check if user cancelled during timeout prompt
        if let current = jobs.first(where: { $0.id == jobID }), current.status == .failed {
            return
        }

        let markdown = MarkdownSerializer.serialize(slides)
        let outputURL = outputURL(for: job.sourceURL)
        do {
            try markdown.write(to: outputURL, atomically: true, encoding: .utf8)
        } catch {
            updateJob(id: jobID, status: .failed,
                      errorMessage: ConverterError.writeFailure(outputURL).errorDescription)
            return
        }
        updateJob(id: jobID, status: .done, outputURL: outputURL)
    }

    private func outputURL(for sourceURL: URL) -> URL {
        let mdFilename = FilenameConverter.convert(sourceURL.lastPathComponent)
        return sourceURL.deletingLastPathComponent().appendingPathComponent(mdFilename)
    }

    private func updateJob(id: UUID, status: JobStatus, outputURL: URL? = nil, errorMessage: String? = nil) {
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        jobs[index].status = status
        if let url = outputURL { jobs[index].outputURL = url }
        if let msg = errorMessage { jobs[index].errorMessage = msg }
    }
}
