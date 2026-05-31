import Foundation

public struct ConversionJob: Identifiable, Equatable {
    public let id: UUID
    public let sourceURL: URL
    public var status: JobStatus
    public var outputURL: URL?
    public var errorMessage: String?

    public init(sourceURL: URL) {
        self.id = UUID()
        self.sourceURL = sourceURL
        self.status = .pending
    }
}

public enum JobStatus: Equatable {
    case pending
    case converting
    case done
    case failed
}
