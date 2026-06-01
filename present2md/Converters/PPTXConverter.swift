import Foundation
import ZIPFoundation

public struct PPTXConverter: FileConverter {
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

        let slideOrder = try readSlideOrder(tmpDir: tmpDir)
        guard !slideOrder.isEmpty else { throw ConverterError.emptyDocument }

        var slides: [Slide] = []
        for relativePath in slideOrder {
            let slideURL = tmpDir.appendingPathComponent(relativePath)
            guard let data = try? Data(contentsOf: slideURL),
                  let xmlStr = String(data: data, encoding: .utf8) else { continue }
            let slide = PPTXSlideParser.parse(xml: xmlStr)
            slides.append(slide)
        }
        if slides.isEmpty { throw ConverterError.emptyDocument }
        return slides
    }

    private func readSlideOrder(tmpDir: URL) throws -> [String] {
        let presentationURL = tmpDir
            .appendingPathComponent("ppt")
            .appendingPathComponent("presentation.xml")
        guard let data = try? Data(contentsOf: presentationURL),
              let xml = String(data: data, encoding: .utf8) else {
            throw ConverterError.corruptArchive
        }
        let relsURL = tmpDir
            .appendingPathComponent("ppt/_rels/presentation.xml.rels")
        guard let relsData = try? Data(contentsOf: relsURL),
              let relsXml = String(data: relsData, encoding: .utf8) else {
            throw ConverterError.corruptArchive
        }
        let rIdToPath = parseRels(relsXml)

        var rIds: [String] = []
        let pattern = #"r:id="([^"]+)""#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        if let lstRange = xml.range(of: "<p:sldIdLst>"),
           let lstEnd = xml.range(of: "</p:sldIdLst>") {
            let sldSection = String(xml[lstRange.lowerBound..<lstEnd.upperBound])
            let sectionRange = NSRange(sldSection.startIndex..., in: sldSection)
            for match in regex.matches(in: sldSection, range: sectionRange) {
                if let r = Range(match.range(at: 1), in: sldSection) {
                    rIds.append(String(sldSection[r]))
                }
            }
        }

        return rIds.compactMap { rId -> String? in
            guard let target = rIdToPath[rId] else { return nil }
            return "ppt/" + target
        }
    }

    private func parseRels(_ xml: String) -> [String: String] {
        var map: [String: String] = [:]
        let pattern = #"Id="([^"]+)"[^>]*Target="([^"]+)""#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return map }
        let range = NSRange(xml.startIndex..., in: xml)
        for match in regex.matches(in: xml, range: range) {
            if let idRange = Range(match.range(at: 1), in: xml),
               let targetRange = Range(match.range(at: 2), in: xml) {
                let id = String(xml[idRange])
                var target = String(xml[targetRange])
                if target.hasPrefix("../") { target = String(target.dropFirst(3)) }
                map[id] = target
            }
        }
        return map
    }
}

private enum PPTXSlideParser {
    static func parse(xml: String) -> Slide {
        let parser = PPTXXMLDelegate()
        let data = xml.data(using: .utf8)!
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = parser
        xmlParser.parse()
        return Slide(title: parser.title, blocks: parser.blocks)
    }
}

private final class PPTXXMLDelegate: NSObject, XMLParserDelegate {
    var title: String? = nil
    var blocks: [SlideBlock] = []

    private var currentText = ""
    private var isInTable = false
    private var tableRows: [[String]] = []
    private var currentRow: [String] = []
    private var currentCell = ""
    private var isInCell = false
    private var phType: String? = nil
    private var textStack: [String] = []

    func parser(_ parser: XMLParser, didStartElement element: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes: [String: String] = [:]) {
        switch element {
        case "p:sp":
            phType = nil
            currentText = ""
        case "p:ph":
            phType = attributes["type"]
        case "a:tbl":
            isInTable = true
            tableRows = []
        case "a:tr":
            currentRow = []
        case "a:tc":
            isInCell = true
            currentCell = ""
        case "a:t":
            textStack.append("")
        default: break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if !textStack.isEmpty {
            textStack[textStack.count - 1] += string
        }
    }

    func parser(_ parser: XMLParser, didEndElement element: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        switch element {
        case "a:t":
            let text = textStack.removeLast()
            if isInCell {
                currentCell += text
            } else {
                currentText += text
            }
        case "a:tc":
            currentRow.append(currentCell.trimmingCharacters(in: .whitespacesAndNewlines))
            currentCell = ""
            isInCell = false
        case "a:tr":
            tableRows.append(currentRow)
        case "a:tbl":
            isInTable = false
            if !tableRows.isEmpty {
                blocks.append(.table(tableRows))
            }
        case "p:sp":
            let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                if phType == "title" || phType == "ctrTitle" {
                    title = text
                } else if !isInTable {
                    blocks.append(.text(text))
                }
            }
            currentText = ""
            phType = nil
        default: break
        }
    }
}
