import Foundation

public protocol FileConverter {
    func convert(url: URL) throws -> [Slide]
}

public enum ConverterError: Error, LocalizedError, Equatable {
    case unreadableFile
    case corruptArchive
    case emptyDocument
    case writeFailure(URL)

    public var errorDescription: String? {
        switch self {
        case .unreadableFile:       return "Cannot read file. Check permissions."
        case .corruptArchive:       return "File appears corrupt or is not a valid PPTX/ODS."
        case .emptyDocument:        return "No content found in file."
        case .writeFailure(let u):  return "Cannot write to \(u.path)."
        }
    }
}

public enum ConverterFactory {
    public static func converter(for url: URL) -> FileConverter? {
        switch url.pathExtension.lowercased() {
        case "pdf":  return PDFConverter()
        case "pptx": return PPTXConverter()
        case "ods":  return ODSConverter()
        default:     return nil
        }
    }
}
