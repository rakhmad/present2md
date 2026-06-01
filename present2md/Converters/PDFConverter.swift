import Foundation
import PDFKit

public struct PDFConverter: FileConverter {
    public init() {}

    public func convert(url: URL) throws -> [Slide] {
        guard let document = PDFDocument(url: url) else {
            throw ConverterError.unreadableFile
        }
        guard document.pageCount > 0 else {
            throw ConverterError.emptyDocument
        }
        var slides: [Slide] = []
        var imageIndex = 1
        for i in 0..<document.pageCount {
            guard let page = document.page(at: i) else { continue }
            slides.append(extractSlide(from: page, imageIndex: &imageIndex))
        }
        return slides
    }

    private func extractSlide(from page: PDFPage, imageIndex: inout Int) -> Slide {
        var blocks: [SlideBlock] = []
        let hasImages = page.annotations.contains { $0.type == "Widget" }
        if hasImages {
            blocks.append(.imagePlaceholder(imageIndex))
            imageIndex += 1
        }

        guard let raw = page.string, !raw.isEmpty else {
            return Slide(title: nil, blocks: blocks)
        }

        let lines = raw.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else {
            return Slide(title: nil, blocks: blocks)
        }

        var title: String? = nil
        var bodyLines = lines
        if lines.count > 1, lines[0].count < 100 {
            title = lines[0]
            bodyLines = Array(lines.dropFirst())
        }

        if let table = detectTable(from: bodyLines) {
            blocks.append(.table(table))
        } else {
            let body = bodyLines.joined(separator: "\n")
            if !body.isEmpty { blocks.append(.text(body)) }
        }

        return Slide(title: title, blocks: blocks)
    }

    private func detectTable(from lines: [String]) -> [[String]]? {
        guard lines.count >= 2 else { return nil }
        guard lines.allSatisfy({ $0.contains("\t") || $0.contains("  ") }) else { return nil }
        let rows = lines.map { line -> [String] in
            if line.contains("\t") {
                return line.components(separatedBy: "\t")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
            } else {
                return line.components(separatedBy: "  ")
                    .filter { !$0.isEmpty }
                    .map { $0.trimmingCharacters(in: .whitespaces) }
            }
        }
        let colCount = rows[0].count
        guard colCount >= 2, rows.allSatisfy({ $0.count == colCount }) else { return nil }
        return rows
    }
}
