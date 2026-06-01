import Foundation
import ZIPFoundation

public struct ODSConverter: FileConverter {
    public init() {}

    public func convert(url: URL) throws -> [Slide] {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ConverterError.unreadableFile
        }
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        do {
            try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
            try FileManager.default.unzipItem(at: url, to: tmpDir)
        } catch {
            throw ConverterError.corruptArchive
        }

        let contentURL = tmpDir.appendingPathComponent("content.xml")
        guard let data = try? Data(contentsOf: contentURL),
              let xml = String(data: data, encoding: .utf8) else {
            throw ConverterError.corruptArchive
        }

        let slides = ODSXMLParser.parse(xml: xml)
        guard !slides.isEmpty else { throw ConverterError.emptyDocument }
        return slides
    }
}

private enum ODSXMLParser {
    static func parse(xml: String) -> [Slide] {
        let delegate = ODSXMLDelegate()
        let parser = XMLParser(data: xml.data(using: .utf8)!)
        parser.delegate = delegate
        parser.parse()
        return delegate.slides
    }
}

private final class ODSXMLDelegate: NSObject, XMLParserDelegate {
    var slides: [Slide] = []

    private var inPage = false
    private var inTextBox = false
    private var isTitle = false
    private var inTable = false
    private var inCell = false
    private var inParagraph = false

    private var currentSlideTitle: String? = nil
    private var currentSlideBlocks: [SlideBlock] = []
    private var currentText = ""
    private var tableRows: [[String]] = []
    private var currentRow: [String] = []
    private var currentCell = ""

    func parser(_ parser: XMLParser, didStartElement element: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes: [String: String] = [:]) {
        switch element {
        case "draw:page":
            inPage = true
            currentSlideTitle = nil
            currentSlideBlocks = []
        case "draw:text-box":
            inTextBox = true
            isTitle = attributes["presentation:class"] == "title"
            currentText = ""
        case "table:table":
            inTable = true
            tableRows = []
        case "table:table-row":
            currentRow = []
        case "table:table-cell":
            inCell = true
            currentCell = ""
        case "text:p":
            inParagraph = true
        default: break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard inParagraph else { return }
        if inCell {
            currentCell += string
        } else if inTextBox {
            currentText += string
        }
    }

    func parser(_ parser: XMLParser, didEndElement element: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        switch element {
        case "text:p":
            inParagraph = false
        case "table:table-cell":
            currentRow.append(currentCell.trimmingCharacters(in: .whitespacesAndNewlines))
            currentCell = ""
            inCell = false
        case "table:table-row":
            tableRows.append(currentRow)
        case "table:table":
            inTable = false
            if !tableRows.isEmpty {
                currentSlideBlocks.append(.table(tableRows))
            }
        case "draw:text-box":
            let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                if isTitle {
                    currentSlideTitle = text
                } else if !inTable {
                    currentSlideBlocks.append(.text(text))
                }
            }
            currentText = ""
            inTextBox = false
            isTitle = false
        case "draw:page":
            slides.append(Slide(title: currentSlideTitle, blocks: currentSlideBlocks))
            inPage = false
        default: break
        }
    }
}
