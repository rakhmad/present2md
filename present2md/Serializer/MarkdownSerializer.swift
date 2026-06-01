import Foundation

public enum MarkdownSerializer {

    public static func serialize(_ slides: [Slide]) -> String {
        var outputParts: [String] = []
        for (index, slide) in slides.enumerated() {
            let section = buildSection(slide: slide, index: index)
            if !section.isEmpty {
                outputParts.append(section)
            }
        }
        return outputParts.joined(separator: "\n\n---\n\n")
    }

    private static func buildSection(slide: Slide, index: Int) -> String {
        var lines: [String] = []
        if let title = slide.title {
            if index == 0 {
                lines.append("---")
                lines.append("title: \(title)")
                lines.append("---")
            } else {
                lines.append("## \(title)")
            }
        }
        for block in slide.blocks {
            let rendered = renderBlock(block)
            if !rendered.isEmpty {
                lines.append("")
                lines.append(rendered)
            }
        }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func renderBlock(_ block: SlideBlock) -> String {
        switch block {
        case .text(let s):
            return s.trimmingCharacters(in: .whitespacesAndNewlines)
        case .table(let rows):
            return renderTable(rows)
        case .imagePlaceholder(let n):
            return "![image](image_\(n).png)"
        }
    }

    private static func renderTable(_ rows: [[String]]) -> String {
        guard let header = rows.first else { return "" }
        var lines: [String] = []
        lines.append(pipeRow(header))
        lines.append(separatorRow(header))
        for row in rows.dropFirst() {
            lines.append(pipeRow(paddedRow(row, count: header.count)))
        }
        return lines.joined(separator: "\n")
    }

    private static func pipeRow(_ cols: [String]) -> String {
        "| " + cols.joined(separator: " | ") + " |"
    }

    private static func separatorRow(_ cols: [String]) -> String {
        "|" + cols.map { String(repeating: "-", count: max($0.count, 3) + 2) }.joined(separator: "|") + "|"
    }

    private static func paddedRow(_ cols: [String], count: Int) -> [String] {
        var result = cols
        while result.count < count { result.append("") }
        return Array(result.prefix(count))
    }
}
