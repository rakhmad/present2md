# present2md Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS SwiftUI app that converts PDF/PPTX/ODS files to CommonMark Markdown, one file or batch, with per-file status UI and Reveal in Finder.

**Architecture:** Three-layer design — SwiftUI UI binds to `ConversionCoordinator` (ObservableObject), which dispatches jobs to format-specific converters conforming to `FileConverter` protocol. Converters produce `[Slide]` structs; `MarkdownSerializer` renders them to CommonMark strings. All conversion runs on detached background Tasks.

**Tech Stack:** Swift 5.9+, SwiftUI, PDFKit, Foundation (XMLParser, FileManager), ZIPFoundation (SPM), macOS 13.0+

---

## File Map

| File | Responsibility |
|---|---|
| `Package.swift` | SPM manifest, ZIPFoundation dependency |
| `present2md/App/present2mdApp.swift` | @main entry, window configuration |
| `present2md/App/ContentView.swift` | Root view, wires toolbar + list + footer |
| `present2md/UI/FileListView.swift` | Scrollable job list, drop target |
| `present2md/UI/FileRowView.swift` | Per-file row: name, spinner, badge, Reveal btn |
| `present2md/UI/EmptyStateView.swift` | Placeholder when jobs array is empty |
| `present2md/Model/ConversionJob.swift` | `ConversionJob` struct + `JobStatus` enum |
| `present2md/Model/Slide.swift` | `Slide` struct |
| `present2md/Model/SlideBlock.swift` | `SlideBlock` enum |
| `present2md/Coordinator/ConversionCoordinator.swift` | ObservableObject, job queue, timeout logic |
| `present2md/Converters/FileConverter.swift` | `FileConverter` protocol + `ConverterFactory` |
| `present2md/Converters/PDFConverter.swift` | PDFKit-based converter |
| `present2md/Converters/PPTXConverter.swift` | ZIP+XML PPTX converter |
| `present2md/Converters/ODSConverter.swift` | ZIP+XML ODS converter |
| `present2md/Serializer/MarkdownSerializer.swift` | `[Slide]` → CommonMark string |
| `present2md/Utilities/FilenameConverter.swift` | snake_case filename sanitizer |
| `present2mdTests/FilenameConverterTests.swift` | Unit tests for filename sanitizer |
| `present2mdTests/MarkdownSerializerTests.swift` | Unit tests for Markdown output |
| `present2mdTests/PPTXConverterTests.swift` | Unit tests for PPTX parsing |
| `present2mdTests/ODSConverterTests.swift` | Unit tests for ODS parsing |
| `present2mdTests/PDFConverterTests.swift` | Unit tests for PDF parsing |
| `present2mdIntegrationTests/ConversionCoordinatorTests.swift` | End-to-end coordinator tests |
| `present2mdPerformanceTests/PerformanceTests.swift` | <60s assertions on large fixtures |
| `scripts/create_test_fixtures.py` | Generates small PPTX/ODS fixture files |
| `scripts/download_test_fixtures.sh` | Downloads + SHA256-verifies large fixtures |

---

## Task 1: Swift Package + Directory Scaffold

**Files:**
- Create: `Package.swift`
- Create: directory tree

- [ ] **Step 1: Create Package.swift**

```swift
// Package.swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "present2md",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "present2mdCore", targets: ["present2mdCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.19"),
    ],
    targets: [
        .target(
            name: "present2mdCore",
            dependencies: ["ZIPFoundation"],
            path: "present2md",
            exclude: ["App", "UI"]
        ),
        .testTarget(
            name: "present2mdTests",
            dependencies: ["present2mdCore"],
            path: "present2mdTests",
            resources: [.copy("../Tests/Fixtures")]
        ),
        .testTarget(
            name: "present2mdIntegrationTests",
            dependencies: ["present2mdCore"],
            path: "present2mdIntegrationTests",
            resources: [.copy("../Tests/Fixtures")]
        ),
        .testTarget(
            name: "present2mdPerformanceTests",
            dependencies: ["present2mdCore"],
            path: "present2mdPerformanceTests",
            resources: [.copy("../Tests/PerformanceFixtures")]
        ),
    ]
)
```

- [ ] **Step 2: Create directory structure**

```bash
mkdir -p present2md/{App,UI,Model,Coordinator,Converters,Serializer,Utilities}
mkdir -p present2mdTests present2mdIntegrationTests present2mdPerformanceTests
mkdir -p Tests/{Fixtures,PerformanceFixtures}
mkdir -p scripts
```

- [ ] **Step 3: Resolve packages**

```bash
swift package resolve
```

Expected: `.build/` created, ZIPFoundation downloaded. No errors.

- [ ] **Step 4: Commit**

```bash
git add Package.swift Package.resolved present2md/ present2mdTests/ present2mdIntegrationTests/ present2mdPerformanceTests/ Tests/ scripts/
git commit -m "feat: scaffold Swift package with ZIPFoundation dependency"
```

---

## Task 2: Data Models

**Files:**
- Create: `present2md/Model/SlideBlock.swift`
- Create: `present2md/Model/Slide.swift`
- Create: `present2md/Model/ConversionJob.swift`

- [ ] **Step 1: Create SlideBlock.swift**

```swift
// present2md/Model/SlideBlock.swift
public enum SlideBlock: Equatable {
    case text(String)
    case table([[String]])
    case imagePlaceholder(Int)
}
```

- [ ] **Step 2: Create Slide.swift**

```swift
// present2md/Model/Slide.swift
public struct Slide: Equatable {
    public var title: String?
    public var blocks: [SlideBlock]

    public init(title: String? = nil, blocks: [SlideBlock] = []) {
        self.title = title
        self.blocks = blocks
    }
}
```

- [ ] **Step 3: Create ConversionJob.swift**

```swift
// present2md/Model/ConversionJob.swift
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
```

- [ ] **Step 4: Verify compilation**

```bash
swift build 2>&1
```

Expected: `Build complete!`

- [ ] **Step 5: Commit**

```bash
git add present2md/Model/
git commit -m "feat: add core data models (Slide, SlideBlock, ConversionJob)"
```

---

## Task 3: FilenameConverter + Tests

**Files:**
- Create: `present2md/Utilities/FilenameConverter.swift`
- Create: `present2mdTests/FilenameConverterTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// present2mdTests/FilenameConverterTests.swift
import XCTest
@testable import present2mdCore

final class FilenameConverterTests: XCTestCase {
    func testBasicSpaces() {
        XCTAssertEqual(FilenameConverter.convert("My Deck.pptx"), "my_deck.md")
    }
    func testHyphens() {
        XCTAssertEqual(FilenameConverter.convert("my-deck.pptx"), "my_deck.md")
    }
    func testEmDash() {
        XCTAssertEqual(FilenameConverter.convert("My Deck \u{2014} 2024.pptx"), "my_deck_2024.md")
    }
    func testEnDash() {
        XCTAssertEqual(FilenameConverter.convert("My Deck \u{2013} 2024.pdf"), "my_deck_2024.md")
    }
    func testParentheses() {
        XCTAssertEqual(FilenameConverter.convert("My Deck (v2).pptx"), "my_deck_v2.md")
    }
    func testFullExample() {
        XCTAssertEqual(FilenameConverter.convert("My Deck \u{2013} 2024 (v2).pptx"), "my_deck_2024_v2.md")
    }
    func testAlreadySnakeCase() {
        XCTAssertEqual(FilenameConverter.convert("my_deck.ods"), "my_deck.md")
    }
    func testAllCaps() {
        XCTAssertEqual(FilenameConverter.convert("QUARTERLY REPORT.pdf"), "quarterly_report.md")
    }
    func testConsecutiveSpaces() {
        XCTAssertEqual(FilenameConverter.convert("my  deck.pptx"), "my_deck.md")
    }
    func testConsecutiveUnderscores() {
        XCTAssertEqual(FilenameConverter.convert("my__deck.pptx"), "my_deck.md")
    }
    func testLeadingTrailingSpaces() {
        XCTAssertEqual(FilenameConverter.convert("  my deck  .pptx"), "my_deck.md")
    }
    func testNumbersPreserved() {
        XCTAssertEqual(FilenameConverter.convert("report 2024 q1.pdf"), "report_2024_q1.md")
    }
    func testDotInName() {
        XCTAssertEqual(FilenameConverter.convert("v1.2 deck.pptx"), "v1_2_deck.md")
    }
    func testAllSpecialChars() {
        XCTAssertEqual(FilenameConverter.convert("!@#$%.pptx"), "_.md")
    }
    func testTruncateTo200Chars() {
        let longName = String(repeating: "a", count: 250) + ".pptx"
        let result = FilenameConverter.convert(longName)
        // 200 stem chars + ".md" = 203 total
        XCTAssertEqual(result.count, 203)
    }
    func testPdfExtension() {
        XCTAssertEqual(FilenameConverter.convert("report.pdf"), "report.md")
    }
    func testOdsExtension() {
        XCTAssertEqual(FilenameConverter.convert("data.ods"), "data.md")
    }
    func testUnderscoreOnlyAfterStrip() {
        XCTAssertEqual(FilenameConverter.convert("--- deck ---.pptx"), "deck.md")
    }
    func testEmptyAfterStrip() {
        XCTAssertEqual(FilenameConverter.convert("---.pptx"), "_.md")
    }
}
```

- [ ] **Step 2: Run tests — verify they fail**

```bash
swift test --filter FilenameConverterTests 2>&1
```

Expected: compile error — `FilenameConverter` not found.

- [ ] **Step 3: Implement FilenameConverter**

```swift
// present2md/Utilities/FilenameConverter.swift
import Foundation

public enum FilenameConverter {
    public static func convert(_ filename: String) -> String {
        var name = (filename as NSString).deletingPathExtension
        name = name.lowercased()
        // Replace whitespace, hyphens, en-dash, em-dash with underscore
        let separators = CharacterSet(charactersIn: " \t\u{2013}\u{2014}-")
        name = name.components(separatedBy: separators).joined(separator: "_")
        // Strip any character that is not a unicode letter, digit, or underscore
        name = name.unicodeScalars.filter { scalar in
            CharacterSet.letters.union(.decimalDigits)
                .union(CharacterSet(charactersIn: "_"))
                .contains(scalar)
        }.map { String($0) }.joined()
        // Collapse consecutive underscores
        while name.contains("__") {
            name = name.replacingOccurrences(of: "__", with: "_")
        }
        // Trim leading/trailing underscores
        name = name.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        if name.isEmpty { name = "_" }
        // Truncate stem to 200 chars
        if name.count > 200 { name = String(name.prefix(200)) }
        return name + ".md"
    }
}
```

- [ ] **Step 4: Run tests — verify they pass**

```bash
swift test --filter FilenameConverterTests 2>&1
```

Expected: `Test Suite 'FilenameConverterTests' passed` (20 tests).

- [ ] **Step 5: Commit**

```bash
git add present2md/Utilities/FilenameConverter.swift present2mdTests/FilenameConverterTests.swift
git commit -m "feat: add FilenameConverter with full test coverage"
```

---

## Task 4: FileConverter Protocol + ConverterFactory

**Files:**
- Create: `present2md/Converters/FileConverter.swift`

- [ ] **Step 1: Write FileConverter.swift**

```swift
// present2md/Converters/FileConverter.swift
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
```

- [ ] **Step 2: Add stub types so the package compiles (stubs will be replaced in Tasks 6–8)**

```swift
// present2md/Converters/PDFConverter.swift  (stub)
import Foundation
public struct PDFConverter: FileConverter {
    public init() {}
    public func convert(url: URL) throws -> [Slide] { return [] }
}
```

```swift
// present2md/Converters/PPTXConverter.swift  (stub)
import Foundation
public struct PPTXConverter: FileConverter {
    public init() {}
    public func convert(url: URL) throws -> [Slide] { return [] }
}
```

```swift
// present2md/Converters/ODSConverter.swift  (stub)
import Foundation
public struct ODSConverter: FileConverter {
    public init() {}
    public func convert(url: URL) throws -> [Slide] { return [] }
}
```

- [ ] **Step 3: Verify compilation**

```bash
swift build 2>&1
```

Expected: `Build complete!`

- [ ] **Step 4: Commit**

```bash
git add present2md/Converters/
git commit -m "feat: add FileConverter protocol, ConverterError, ConverterFactory, stub converters"
```

---

## Task 5: MarkdownSerializer + Tests

**Files:**
- Create: `present2md/Serializer/MarkdownSerializer.swift`
- Create: `present2mdTests/MarkdownSerializerTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// present2mdTests/MarkdownSerializerTests.swift
import XCTest
@testable import present2mdCore

final class MarkdownSerializerTests: XCTestCase {

    func testSingleSlideWithTitle() {
        let slides = [Slide(title: "Hello World", blocks: [.text("Body text.")])]
        let result = MarkdownSerializer.serialize(slides)
        XCTAssertTrue(result.contains("---\ntitle: Hello World\n---"))
        XCTAssertTrue(result.contains("Body text."))
    }

    func testFirstSlideTitleInFrontmatter() {
        let slides = [Slide(title: "First", blocks: [])]
        let result = MarkdownSerializer.serialize(slides)
        XCTAssertTrue(result.hasPrefix("---\ntitle: First\n---"))
    }

    func testSecondSlideTitleIsHeading() {
        let slides = [
            Slide(title: "First", blocks: []),
            Slide(title: "Second", blocks: [.text("Content")])
        ]
        let result = MarkdownSerializer.serialize(slides)
        XCTAssertTrue(result.contains("## Second"))
        XCTAssertFalse(result.components(separatedBy: "---").dropFirst(2).joined().contains("title:"))
    }

    func testSlidesSeparatedByThematicBreak() {
        let slides = [
            Slide(title: "A", blocks: [.text("one")]),
            Slide(title: "B", blocks: [.text("two")])
        ]
        let result = MarkdownSerializer.serialize(slides)
        // The separator --- appears between slides
        let parts = result.components(separatedBy: "\n---\n")
        XCTAssertGreaterThanOrEqual(parts.count, 2)
    }

    func testTableBlock() {
        let slides = [Slide(title: nil, blocks: [
            .table([["Col A", "Col B"], ["val 1", "val 2"]])
        ])]
        let result = MarkdownSerializer.serialize(slides)
        XCTAssertTrue(result.contains("| Col A | Col B |"))
        XCTAssertTrue(result.contains("|-------|-------|"))
        XCTAssertTrue(result.contains("| val 1 | val 2 |"))
    }

    func testTableSingleRowBecomesHeaderOnly() {
        let slides = [Slide(title: nil, blocks: [
            .table([["Only", "Header"]])
        ])]
        let result = MarkdownSerializer.serialize(slides)
        XCTAssertTrue(result.contains("| Only | Header |"))
        XCTAssertTrue(result.contains("|------|--------|"))
    }

    func testImagePlaceholder() {
        let slides = [Slide(title: nil, blocks: [.imagePlaceholder(3)])]
        let result = MarkdownSerializer.serialize(slides)
        XCTAssertTrue(result.contains("![image](image_3.png)"))
    }

    func testEmptySlideProducesNoContent() {
        let slides = [Slide(title: nil, blocks: [])]
        let result = MarkdownSerializer.serialize(slides)
        XCTAssertTrue(result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    func testNoTitleMeansNoFrontmatter() {
        let slides = [Slide(title: nil, blocks: [.text("Just text")])]
        let result = MarkdownSerializer.serialize(slides)
        XCTAssertFalse(result.contains("title:"))
        XCTAssertTrue(result.contains("Just text"))
    }

    func testMultipleTextBlocksAllPresent() {
        let slides = [Slide(title: "T", blocks: [.text("Alpha"), .text("Beta")])]
        let result = MarkdownSerializer.serialize(slides)
        XCTAssertTrue(result.contains("Alpha"))
        XCTAssertTrue(result.contains("Beta"))
    }
}
```

- [ ] **Step 2: Run — verify failure**

```bash
swift test --filter MarkdownSerializerTests 2>&1
```

Expected: compile error — `MarkdownSerializer` not found.

- [ ] **Step 3: Implement MarkdownSerializer**

```swift
// present2md/Serializer/MarkdownSerializer.swift
import Foundation

public enum MarkdownSerializer {

    public static func serialize(_ slides: [Slide]) -> String {
        var outputParts: [String] = []
        for (index, slide) in slides.enumerated() {
            var section = buildSection(slide: slide, index: index)
            if !section.isEmpty {
                outputParts.append(section)
            }
        }
        return outputParts.joined(separator: "\n\n---\n\n")
    }

    private static func buildSection(slide: Slide, index: Int) -> String {
        var lines: [String] = []
        // Header
        if let title = slide.title {
            if index == 0 {
                lines.append("---")
                lines.append("title: \(title)")
                lines.append("---")
            } else {
                lines.append("## \(title)")
            }
        }
        // Blocks
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
        "| " + cols.map { String(repeating: "-", count: max($0.count, 3)) }.joined(separator: " | ") + " |"
    }

    private static func paddedRow(_ cols: [String], count: Int) -> [String] {
        var result = cols
        while result.count < count { result.append("") }
        return Array(result.prefix(count))
    }
}
```

- [ ] **Step 4: Run — verify passing**

```bash
swift test --filter MarkdownSerializerTests 2>&1
```

Expected: `Test Suite 'MarkdownSerializerTests' passed` (10 tests).

- [ ] **Step 5: Commit**

```bash
git add present2md/Serializer/MarkdownSerializer.swift present2mdTests/MarkdownSerializerTests.swift
git commit -m "feat: add MarkdownSerializer with CommonMark output and full tests"
```

---

## Task 6: Test Fixture Generator Script

**Files:**
- Create: `scripts/create_test_fixtures.py`

- [ ] **Step 1: Write fixture generator**

```python
#!/usr/bin/env python3
# scripts/create_test_fixtures.py
# Generates minimal PPTX and ODS files for unit tests (no external deps needed).
import zipfile, os

FIXTURES = "Tests/Fixtures"
os.makedirs(FIXTURES, exist_ok=True)

# ── PPTX ──────────────────────────────────────────────────────────────────────
RELS = '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
SLIDE1 = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"
       xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
       xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <p:cSld><p:spTree>
    <p:sp><p:nvSpPr><p:nvPr><p:ph type="title"/></p:nvPr></p:nvSpPr>
      <p:txBody><a:p><a:r><a:t>Slide One Title</a:t></a:r></a:p></p:txBody></p:sp>
    <p:sp><p:nvSpPr><p:nvPr><p:ph type="body"/></p:nvPr></p:nvSpPr>
      <p:txBody><a:p><a:r><a:t>Body text for slide one.</a:t></a:r></a:p></p:txBody></p:sp>
  </p:spTree></p:cSld>
</p:sld>'''

SLIDE2 = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"
       xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
       xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <p:cSld><p:spTree>
    <p:sp><p:nvSpPr><p:nvPr><p:ph type="title"/></p:nvPr></p:nvSpPr>
      <p:txBody><a:p><a:r><a:t>Slide Two Title</a:t></a:r></a:p></p:txBody></p:sp>
    <p:sp><p:nvSpPr><p:nvPr></p:nvPr></p:nvSpPr>
      <p:txBody>
        <a:tbl><a:tr>
          <a:tc><a:txBody><a:p><a:r><a:t>Col A</a:t></a:r></a:p></a:txBody></a:tc>
          <a:tc><a:txBody><a:p><a:r><a:t>Col B</a:t></a:r></a:p></a:txBody></a:tc>
        </a:tr><a:tr>
          <a:tc><a:txBody><a:p><a:r><a:t>val 1</a:t></a:r></a:p></a:txBody></a:tc>
          <a:tc><a:txBody><a:p><a:r><a:t>val 2</a:t></a:r></a:p></a:txBody></a:tc>
        </a:tr></a:tbl>
      </p:txBody></p:sp>
  </p:spTree></p:cSld>
</p:sld>'''

PRESENTATION = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:presentation xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"
                xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <p:sldMasterIdLst/>
  <p:sldIdLst>
    <p:sldId id="256" r:id="rId1"/>
    <p:sldId id="257" r:id="rId2"/>
  </p:sldIdLst>
</p:presentation>'''

PRES_RELS = RELS + '''
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide1.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide2.xml"/>
</Relationships>'''

CONTENT_TYPES = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>
  <Override PartName="/ppt/slides/slide1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>
  <Override PartName="/ppt/slides/slide2.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>
</Types>'''

ROOT_RELS = RELS + '''
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>
</Relationships>'''

pptx_path = os.path.join(FIXTURES, "sample.pptx")
with zipfile.ZipFile(pptx_path, "w", zipfile.ZIP_DEFLATED) as z:
    z.writestr("[Content_Types].xml", CONTENT_TYPES)
    z.writestr("_rels/.rels", ROOT_RELS)
    z.writestr("ppt/presentation.xml", PRESENTATION)
    z.writestr("ppt/_rels/presentation.xml.rels", PRES_RELS)
    z.writestr("ppt/slides/slide1.xml", SLIDE1)
    z.writestr("ppt/slides/slide2.xml", SLIDE2)
print(f"Created {pptx_path}")

# ── ODS ───────────────────────────────────────────────────────────────────────
ODS_CONTENT = '''<?xml version="1.0" encoding="UTF-8"?>
<office:document-content
  xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0"
  xmlns:draw="urn:oasis:names:tc:opendocument:xmlns:drawing:1.0"
  xmlns:presentation="urn:oasis:names:tc:opendocument:xmlns:presentation:1.0"
  xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0"
  xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0">
  <office:body><office:presentation>
    <draw:page draw:name="Slide1">
      <draw:text-box presentation:class="title"><text:p>ODS Slide One</text:p></draw:text-box>
      <draw:text-box><text:p>ODS body text here.</text:p></draw:text-box>
    </draw:page>
    <draw:page draw:name="Slide2">
      <draw:text-box presentation:class="title"><text:p>ODS Slide Two</text:p></draw:text-box>
      <draw:text-box>
        <table:table>
          <table:table-row>
            <table:table-cell><text:p>Header A</text:p></table:table-cell>
            <table:table-cell><text:p>Header B</text:p></table:table-cell>
          </table:table-row>
          <table:table-row>
            <table:table-cell><text:p>Row 1A</text:p></table:table-cell>
            <table:table-cell><text:p>Row 1B</text:p></table:table-cell>
          </table:table-row>
        </table:table>
      </draw:text-box>
    </draw:page>
  </office:presentation></office:body>
</office:document-content>'''

ODS_MANIFEST = '''<?xml version="1.0" encoding="UTF-8"?>
<manifest:manifest xmlns:manifest="urn:oasis:names:tc:opendocument:xmlns:manifest:1.0">
  <manifest:file-entry manifest:full-path="/" manifest:media-type="application/vnd.oasis.opendocument.presentation"/>
  <manifest:file-entry manifest:full-path="content.xml" manifest:media-type="text/xml"/>
</manifest:manifest>'''

ods_path = os.path.join(FIXTURES, "sample.ods")
with zipfile.ZipFile(ods_path, "w", zipfile.ZIP_DEFLATED) as z:
    z.writestr("mimetype", "application/vnd.oasis.opendocument.presentation")
    z.writestr("content.xml", ODS_CONTENT)
    z.writestr("META-INF/manifest.xml", ODS_MANIFEST)
print(f"Created {ods_path}")
```

- [ ] **Step 2: Run the script to generate fixtures**

```bash
python3 scripts/create_test_fixtures.py
```

Expected:
```
Created Tests/Fixtures/sample.pptx
Created Tests/Fixtures/sample.ods
```

- [ ] **Step 3: Commit**

```bash
git add scripts/create_test_fixtures.py Tests/Fixtures/
git commit -m "test: add fixture generator and sample PPTX/ODS test fixtures"
```

---

## Task 7: PPTXConverter + Tests

**Files:**
- Modify: `present2md/Converters/PPTXConverter.swift` (replace stub)
- Create: `present2mdTests/PPTXConverterTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// present2mdTests/PPTXConverterTests.swift
import XCTest
@testable import present2mdCore

final class PPTXConverterTests: XCTestCase {

    private var fixtureURL: URL {
        // Bundle resource copied by Package.swift resources rule
        Bundle.module.url(forResource: "sample", withExtension: "pptx",
                          subdirectory: "Fixtures")!
    }

    func testSlideCount() throws {
        let slides = try PPTXConverter().convert(url: fixtureURL)
        XCTAssertEqual(slides.count, 2)
    }

    func testFirstSlideTitle() throws {
        let slides = try PPTXConverter().convert(url: fixtureURL)
        XCTAssertEqual(slides[0].title, "Slide One Title")
    }

    func testFirstSlideBodyText() throws {
        let slides = try PPTXConverter().convert(url: fixtureURL)
        let texts = slides[0].blocks.compactMap { if case .text(let t) = $0 { return t } else { return nil } }
        XCTAssertTrue(texts.joined().contains("Body text for slide one."))
    }

    func testSecondSlideTitle() throws {
        let slides = try PPTXConverter().convert(url: fixtureURL)
        XCTAssertEqual(slides[1].title, "Slide Two Title")
    }

    func testSecondSlideHasTable() throws {
        let slides = try PPTXConverter().convert(url: fixtureURL)
        let tables = slides[1].blocks.compactMap { if case .table(let t) = $0 { return t } else { return nil } }
        XCTAssertFalse(tables.isEmpty)
        XCTAssertEqual(tables[0][0], ["Col A", "Col B"])
        XCTAssertEqual(tables[0][1], ["val 1", "val 2"])
    }

    func testCorruptFileThrows() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".pptx")
        try "not a zip".write(to: url, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try PPTXConverter().convert(url: url)) { error in
            XCTAssertEqual(error as? ConverterError, .corruptArchive)
        }
    }

    func testUnreadableFileThrows() throws {
        let url = URL(fileURLWithPath: "/nonexistent/path/file.pptx")
        XCTAssertThrowsError(try PPTXConverter().convert(url: url)) { error in
            XCTAssertEqual(error as? ConverterError, .unreadableFile)
        }
    }
}
```

- [ ] **Step 2: Run — verify failure**

```bash
swift test --filter PPTXConverterTests 2>&1
```

Expected: tests fail (stub returns empty array).

- [ ] **Step 3: Implement PPTXConverter (replace stub)**

```swift
// present2md/Converters/PPTXConverter.swift
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

    // Reads ppt/presentation.xml and returns ordered relative paths to slide XMLs
    private func readSlideOrder(tmpDir: URL) throws -> [String] {
        let presentationURL = tmpDir
            .appendingPathComponent("ppt")
            .appendingPathComponent("presentation.xml")
        guard let data = try? Data(contentsOf: presentationURL),
              let xml = String(data: data, encoding: .utf8) else {
            throw ConverterError.corruptArchive
        }
        // Parse ppt/_rels/presentation.xml.rels to map rId → slide path
        let relsURL = tmpDir
            .appendingPathComponent("ppt/_rels/presentation.xml.rels")
        guard let relsData = try? Data(contentsOf: relsURL),
              let relsXml = String(data: relsData, encoding: .utf8) else {
            throw ConverterError.corruptArchive
        }
        let rIdToPath = parseRels(relsXml)

        // Extract rId order from sldIdLst
        var rIds: [String] = []
        let pattern = #"r:id="([^"]+)""#
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(xml.startIndex..., in: xml)
        // Only capture rIds that appear inside <p:sldIdLst>
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
            // target is relative to ppt/, e.g. "slides/slide1.xml"
            return "ppt/" + target
        }
    }

    private func parseRels(_ xml: String) -> [String: String] {
        var map: [String: String] = [:]
        // Match Id="..." Target="..."
        let pattern = #"Id="([^"]+)"[^>]*Target="([^"]+)""#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return map }
        let range = NSRange(xml.startIndex..., in: xml)
        for match in regex.matches(in: xml, range: range) {
            if let idRange = Range(match.range(at: 1), in: xml),
               let targetRange = Range(match.range(at: 2), in: xml) {
                let id = String(xml[idRange])
                var target = String(xml[targetRange])
                // Remove leading "../" if present
                if target.hasPrefix("../") { target = String(target.dropFirst(3)) }
                map[id] = target
            }
        }
        return map
    }
}

// Parses a single slide XML into a Slide struct
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
    private var isInTitle = false
    private var isInTable = false
    private var tableRows: [[String]] = []
    private var currentRow: [String] = []
    private var currentCell = ""
    private var isInCell = false
    private var phType: String? = nil
    private var spStack: [String] = []
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
```

- [ ] **Step 4: Run tests — verify passing**

```bash
swift test --filter PPTXConverterTests 2>&1
```

Expected: `Test Suite 'PPTXConverterTests' passed` (6 tests).

- [ ] **Step 5: Commit**

```bash
git add present2md/Converters/PPTXConverter.swift present2mdTests/PPTXConverterTests.swift
git commit -m "feat: implement PPTXConverter with ZIP+XML parsing and tests"
```

---

## Task 8: ODSConverter + Tests

**Files:**
- Modify: `present2md/Converters/ODSConverter.swift` (replace stub)
- Create: `present2mdTests/ODSConverterTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// present2mdTests/ODSConverterTests.swift
import XCTest
@testable import present2mdCore

final class ODSConverterTests: XCTestCase {

    private var fixtureURL: URL {
        Bundle.module.url(forResource: "sample", withExtension: "ods",
                          subdirectory: "Fixtures")!
    }

    func testSlideCount() throws {
        let slides = try ODSConverter().convert(url: fixtureURL)
        XCTAssertEqual(slides.count, 2)
    }

    func testFirstSlideTitle() throws {
        let slides = try ODSConverter().convert(url: fixtureURL)
        XCTAssertEqual(slides[0].title, "ODS Slide One")
    }

    func testFirstSlideBodyText() throws {
        let slides = try ODSConverter().convert(url: fixtureURL)
        let texts = slides[0].blocks.compactMap { if case .text(let t) = $0 { return t } else { return nil } }
        XCTAssertTrue(texts.joined().contains("ODS body text here."))
    }

    func testSecondSlideTitle() throws {
        let slides = try ODSConverter().convert(url: fixtureURL)
        XCTAssertEqual(slides[1].title, "ODS Slide Two")
    }

    func testSecondSlideHasTable() throws {
        let slides = try ODSConverter().convert(url: fixtureURL)
        let tables = slides[1].blocks.compactMap { if case .table(let t) = $0 { return t } else { return nil } }
        XCTAssertFalse(tables.isEmpty)
        XCTAssertEqual(tables[0][0], ["Header A", "Header B"])
        XCTAssertEqual(tables[0][1], ["Row 1A", "Row 1B"])
    }

    func testCorruptFileThrows() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".ods")
        try "not a zip".write(to: url, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try ODSConverter().convert(url: url)) { error in
            XCTAssertEqual(error as? ConverterError, .corruptArchive)
        }
    }

    func testUnreadableFileThrows() throws {
        let url = URL(fileURLWithPath: "/nonexistent/path/file.ods")
        XCTAssertThrowsError(try ODSConverter().convert(url: url)) { error in
            XCTAssertEqual(error as? ConverterError, .unreadableFile)
        }
    }
}
```

- [ ] **Step 2: Run — verify failure**

```bash
swift test --filter ODSConverterTests 2>&1
```

Expected: tests fail (stub returns empty array).

- [ ] **Step 3: Implement ODSConverter (replace stub)**

```swift
// present2md/Converters/ODSConverter.swift
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
```

- [ ] **Step 4: Run tests — verify passing**

```bash
swift test --filter ODSConverterTests 2>&1
```

Expected: `Test Suite 'ODSConverterTests' passed` (6 tests).

- [ ] **Step 5: Commit**

```bash
git add present2md/Converters/ODSConverter.swift present2mdTests/ODSConverterTests.swift
git commit -m "feat: implement ODSConverter with ZIP+XML parsing and tests"
```

---

## Task 9: PDFConverter + Tests (full implementation)

**Files:**
- Modify: `present2md/Converters/PDFConverter.swift` (replace stub)
- Create: `present2mdTests/PDFConverterTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// present2mdTests/PDFConverterTests.swift
import XCTest
import PDFKit
@testable import present2mdCore

final class PDFConverterTests: XCTestCase {

    private func writePDF(_ document: PDFDocument) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".pdf")
        guard document.write(to: url) else { throw ConverterError.writeFailure(url) }
        return url
    }

    func testEmptyPDFThrows() throws {
        let url = try writePDF(PDFDocument())
        XCTAssertThrowsError(try PDFConverter().convert(url: url)) { error in
            XCTAssertEqual(error as? ConverterError, .emptyDocument)
        }
    }

    func testUnreadableFileThrows() {
        let url = URL(fileURLWithPath: "/no/such/file.pdf")
        XCTAssertThrowsError(try PDFConverter().convert(url: url)) { error in
            XCTAssertEqual(error as? ConverterError, .unreadableFile)
        }
    }

    func testPageCountMatchesSlideCount() throws {
        let doc = PDFDocument()
        doc.insert(PDFPage(), at: 0)
        doc.insert(PDFPage(), at: 1)
        doc.insert(PDFPage(), at: 2)
        let url = try writePDF(doc)
        let slides = try PDFConverter().convert(url: url)
        XCTAssertEqual(slides.count, 3)
    }

    func testEmptyPageProducesSlideWithNoBlocks() throws {
        let doc = PDFDocument()
        doc.insert(PDFPage(), at: 0)
        let url = try writePDF(doc)
        let slides = try PDFConverter().convert(url: url)
        XCTAssertEqual(slides[0].blocks.count, 0)
        XCTAssertNil(slides[0].title)
    }
}
```

- [ ] **Step 2: Run — verify failure**

```bash
swift test --filter PDFConverterTests 2>&1
```

Expected: tests fail (stub returns empty array).

- [ ] **Step 3: Implement PDFConverter (replace stub)**

```swift
// present2md/Converters/PDFConverter.swift
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
        // Image annotations → placeholder
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
        // Heuristic: if first line is short (<100 chars) and more lines follow,
        // treat it as the slide title
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

    // Returns a 2D table if every line contains consistent tab or multi-space delimiters
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
```

- [ ] **Step 4: Run tests — verify passing**

```bash
swift test --filter PDFConverterTests 2>&1
```

Expected: `Test Suite 'PDFConverterTests' passed` (4 tests).

- [ ] **Step 5: Run all unit tests**

```bash
swift test --filter present2mdTests 2>&1
```

Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add present2md/Converters/PDFConverter.swift present2mdTests/PDFConverterTests.swift
git commit -m "feat: implement PDFConverter with PDFKit extraction and tests"
```

---

## Task 10: ConversionCoordinator

**Files:**
- Create: `present2md/Coordinator/ConversionCoordinator.swift`

- [ ] **Step 1: Implement ConversionCoordinator**

```swift
// present2md/Coordinator/ConversionCoordinator.swift
import Foundation
import Combine

@MainActor
public final class ConversionCoordinator: ObservableObject {
    @Published public var jobs: [ConversionJob] = []
    @Published public var timeoutJobID: UUID? = nil  // non-nil triggers the alert sheet

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

    // Called from UI when user taps "Keep Waiting" in the timeout sheet
    public func continueJob(id: UUID) {
        timeoutJobID = nil
    }

    // Called from UI when user taps "Cancel" in the timeout sheet
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

        var keepWaiting = true
        var timedOut = false

        // Timeout watchdog
        let watchdog = Task { [weak self] in
            try await Task.sleep(nanoseconds: UInt64((self?.timeoutSeconds ?? 60) * 1_000_000_000))
            guard let self else { return }
            await MainActor.run {
                self.timeoutJobID = jobID
            }
            // Wait for user response (poll timeoutJobID clearing)
            while await MainActor.run(body: { self.timeoutJobID == jobID }) {
                try await Task.sleep(nanoseconds: 500_000_000)
            }
            // If job was cancelled, timedOut stays false; run() will see .failed
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
            updateJob(id: jobID, status: .failed, errorMessage: ConverterError.writeFailure(outputURL).errorDescription)
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
```

- [ ] **Step 2: Verify compilation**

```bash
swift build 2>&1
```

Expected: `Build complete!`

- [ ] **Step 3: Commit**

```bash
git add present2md/Coordinator/ConversionCoordinator.swift
git commit -m "feat: add ConversionCoordinator with job queue and 60s timeout prompt"
```

---

## Task 11: Integration Tests

**Files:**
- Create: `present2mdIntegrationTests/ConversionCoordinatorTests.swift`

- [ ] **Step 1: Write integration tests**

```swift
// present2mdIntegrationTests/ConversionCoordinatorTests.swift
import XCTest
@testable import present2mdCore

@MainActor
final class ConversionCoordinatorTests: XCTestCase {

    private var pptxFixture: URL {
        Bundle.module.url(forResource: "sample", withExtension: "pptx",
                          subdirectory: "Fixtures")!
    }
    private var odsFixture: URL {
        Bundle.module.url(forResource: "sample", withExtension: "ods",
                          subdirectory: "Fixtures")!
    }

    func testPPTXEndToEnd() async throws {
        // Copy fixture to tmp so output lands in a writable dir
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".pptx")
        try FileManager.default.copyItem(at: pptxFixture, to: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let coordinator = ConversionCoordinator()
        coordinator.addJobs(urls: [tmp])

        // Poll until job completes (max 10s)
        let deadline = Date().addingTimeInterval(10)
        while coordinator.jobs.first?.status == .converting || coordinator.jobs.first?.status == .pending {
            guard Date() < deadline else { XCTFail("Timeout waiting for conversion"); return }
            try await Task.sleep(nanoseconds: 100_000_000)
        }

        let job = try XCTUnwrap(coordinator.jobs.first)
        XCTAssertEqual(job.status, .done)
        let outputURL = try XCTUnwrap(job.outputURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
        let content = try String(contentsOf: outputURL, encoding: .utf8)
        XCTAssertTrue(content.contains("Slide One Title"))
        XCTAssertTrue(content.contains("Slide Two Title"))
        try? FileManager.default.removeItem(at: outputURL)
    }

    func testODSEndToEnd() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".ods")
        try FileManager.default.copyItem(at: odsFixture, to: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let coordinator = ConversionCoordinator()
        coordinator.addJobs(urls: [tmp])

        let deadline = Date().addingTimeInterval(10)
        while coordinator.jobs.first?.status == .converting || coordinator.jobs.first?.status == .pending {
            guard Date() < deadline else { XCTFail("Timeout waiting for conversion"); return }
            try await Task.sleep(nanoseconds: 100_000_000)
        }

        let job = try XCTUnwrap(coordinator.jobs.first)
        XCTAssertEqual(job.status, .done)
        let content = try String(contentsOf: try XCTUnwrap(job.outputURL), encoding: .utf8)
        XCTAssertTrue(content.contains("ODS Slide One"))
        try? FileManager.default.removeItem(at: job.outputURL!)
    }

    func testUnsupportedFileTypeFails() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".txt")
        try "hello".write(to: tmp, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let coordinator = ConversionCoordinator()
        coordinator.addJobs(urls: [tmp])

        let deadline = Date().addingTimeInterval(5)
        while coordinator.jobs.first?.status == .converting || coordinator.jobs.first?.status == .pending {
            guard Date() < deadline else { XCTFail("Timeout"); return }
            try await Task.sleep(nanoseconds: 100_000_000)
        }

        XCTAssertEqual(coordinator.jobs.first?.status, .failed)
    }

    func testOutputFilenameIsSnakeCase() async throws {
        // Copy fixture with a spaced name
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("My Sample Deck.pptx")
        try FileManager.default.copyItem(at: pptxFixture, to: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let coordinator = ConversionCoordinator()
        coordinator.addJobs(urls: [tmp])

        let deadline = Date().addingTimeInterval(10)
        while coordinator.jobs.first?.status == .converting || coordinator.jobs.first?.status == .pending {
            guard Date() < deadline else { XCTFail("Timeout"); return }
            try await Task.sleep(nanoseconds: 100_000_000)
        }

        let outputURL = try XCTUnwrap(coordinator.jobs.first?.outputURL)
        XCTAssertEqual(outputURL.lastPathComponent, "my_sample_deck.md")
        try? FileManager.default.removeItem(at: outputURL)
    }

    func testClearCompletedRemovesDoneJobs() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".pptx")
        try FileManager.default.copyItem(at: pptxFixture, to: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let coordinator = ConversionCoordinator()
        coordinator.addJobs(urls: [tmp])

        let deadline = Date().addingTimeInterval(10)
        while coordinator.jobs.first?.status == .converting || coordinator.jobs.first?.status == .pending {
            guard Date() < deadline else { XCTFail("Timeout"); return }
            try await Task.sleep(nanoseconds: 100_000_000)
        }

        coordinator.clearCompleted()
        XCTAssertTrue(coordinator.jobs.isEmpty)
        try? FileManager.default.removeItem(at: coordinator.jobs.first?.outputURL ?? tmp)
    }
}
```

- [ ] **Step 2: Run integration tests**

```bash
swift test --filter present2mdIntegrationTests 2>&1
```

Expected: `Test Suite 'ConversionCoordinatorTests' passed` (5 tests).

- [ ] **Step 3: Commit**

```bash
git add present2mdIntegrationTests/ConversionCoordinatorTests.swift
git commit -m "test: add end-to-end integration tests for ConversionCoordinator"
```

---

## Task 12: Performance Test Fixtures + Tests

**Files:**
- Create: `scripts/download_test_fixtures.sh`
- Create: `present2mdPerformanceTests/PerformanceTests.swift`

- [ ] **Step 1: Write fixture download script**

```bash
#!/usr/bin/env bash
# scripts/download_test_fixtures.sh
# Downloads large public-domain files for performance testing.
set -euo pipefail

DEST="Tests/PerformanceFixtures"
mkdir -p "$DEST"

download_and_verify() {
    local url="$1" dest="$2" expected_sha="$3"
    if [[ -f "$dest" ]]; then
        echo "Already exists: $dest"
        return
    fi
    echo "Downloading $dest ..."
    curl -fsSL "$url" -o "$dest"
    actual_sha=$(shasum -a 256 "$dest" | awk '{print $1}')
    if [[ "$actual_sha" != "$expected_sha" ]]; then
        echo "ERROR: SHA256 mismatch for $dest"
        echo "  Expected: $expected_sha"
        echo "  Actual:   $actual_sha"
        rm -f "$dest"
        exit 1
    fi
    echo "OK: $dest"
}

# NASA Technical Report (public domain PDF, ~100 pages)
download_and_verify \
  "https://ntrs.nasa.gov/api/citations/19930083591/downloads/19930083591.pdf" \
  "$DEST/nasa_large.pdf" \
  "PLACEHOLDER_SHA256_nasa"

# UN General Assembly background guide (public domain PPTX, 50+ slides)
# Using a World Bank open data presentation as substitute:
download_and_verify \
  "https://documents1.worldbank.org/curated/en/sample-presentation.pptx" \
  "$DEST/large_sample.pptx" \
  "PLACEHOLDER_SHA256_pptx"

echo "All performance fixtures downloaded."
```

> **Note:** Before committing this script, run it once and replace `PLACEHOLDER_SHA256_*` with the actual SHA256 outputs printed during download. The script self-verifies on all subsequent runs.

- [ ] **Step 2: Run the script and capture real SHA256 values**

```bash
bash scripts/download_test_fixtures.sh 2>&1
# If URLs return 404, find equivalent public-domain large files and update URLs
shasum -a 256 Tests/PerformanceFixtures/*
```

Update the script with the real SHA256 values from the output above before continuing.

- [ ] **Step 3: Write performance tests**

```swift
// present2mdPerformanceTests/PerformanceTests.swift
import XCTest
@testable import present2mdCore

final class PerformanceTests: XCTestCase {

    private func fixtureURL(name: String, ext: String) throws -> URL {
        guard let url = Bundle.module.url(forResource: name, withExtension: ext,
                                          subdirectory: "PerformanceFixtures") else {
            throw XCTSkip("Performance fixture '\(name).\(ext)' not found — run scripts/download_test_fixtures.sh")
        }
        return url
    }

    func testLargePDFConvertsUnder60Seconds() throws {
        let url = try fixtureURL(name: "nasa_large", ext: "pdf")
        let converter = PDFConverter()
        let start = Date()
        let slides = try converter.convert(url: url)
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertGreaterThan(slides.count, 50, "Expected >50 pages")
        XCTAssertLessThan(elapsed, 60, "PDF conversion took \(elapsed)s — exceeds 60s limit")
    }

    func testLargePPTXConvertsUnder60Seconds() throws {
        let url = try fixtureURL(name: "large_sample", ext: "pptx")
        let converter = PPTXConverter()
        let start = Date()
        let slides = try converter.convert(url: url)
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertGreaterThan(slides.count, 10, "Expected >10 slides")
        XCTAssertLessThan(elapsed, 60, "PPTX conversion took \(elapsed)s — exceeds 60s limit")
    }
}
```

- [ ] **Step 4: Run performance tests (requires fixtures)**

```bash
bash scripts/download_test_fixtures.sh
swift test --filter PerformanceTests 2>&1
```

Expected: both tests pass under 60 seconds. If a fixture URL is unavailable, the test is skipped (not failed).

- [ ] **Step 5: Commit**

```bash
git add scripts/download_test_fixtures.sh present2mdPerformanceTests/PerformanceTests.swift
git commit -m "test: add performance tests and fixture download script"
```

---

## Task 13: SwiftUI App — Entry Point + Xcode Project

**Files:**
- Create: `present2md/App/present2mdApp.swift`
- Create: `present2md/App/ContentView.swift`

> This task requires Xcode to create the `.xcodeproj`. The SPM core library is already testable without it.

- [ ] **Step 1: Create Xcode project**

Open Xcode → File → New → Project → macOS → App.
- Product Name: `present2md`
- Bundle ID: `com.rakhmad.present2md`
- Interface: SwiftUI
- Language: Swift
- Minimum Deployment: macOS 13.0
- Uncheck "Include Tests" (tests are already in SPM targets)

Save into `/Users/razhari/tmp/present2md/` (the existing directory).

- [ ] **Step 2: Write present2mdApp.swift**

```swift
// present2md/App/present2mdApp.swift
import SwiftUI

@main
struct present2mdApp: App {
    @StateObject private var coordinator = ConversionCoordinator()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(coordinator)
                .frame(minWidth: 480, minHeight: 320)
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
```

- [ ] **Step 3: Write ContentView.swift**

```swift
// present2md/App/ContentView.swift
import SwiftUI
import AppKit

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
        panel.allowedContentTypes = [.pdf,
                                     .init(filenameExtension: "pptx")!,
                                     .init(filenameExtension: "ods")!]
        panel.begin { response in
            guard response == .OK else { return }
            coordinator.addJobs(urls: panel.urls)
        }
    }
}
```

- [ ] **Step 4: Commit**

```bash
git add present2md/App/
git commit -m "feat: add SwiftUI app entry point and ContentView with toolbar and footer"
```

---

## Task 14: SwiftUI App — UI Components

**Files:**
- Create: `present2md/UI/EmptyStateView.swift`
- Create: `present2md/UI/FileListView.swift`
- Create: `present2md/UI/FileRowView.swift`
- Create: `present2md/UI/TimeoutAlertView.swift`

- [ ] **Step 1: Write EmptyStateView.swift**

```swift
// present2md/UI/EmptyStateView.swift
import SwiftUI

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.badge.arrow.up")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("Browse or drop files to begin conversion")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

- [ ] **Step 2: Write FileListView.swift**

```swift
// present2md/UI/FileListView.swift
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
```

- [ ] **Step 3: Write FileRowView.swift**

```swift
// present2md/UI/FileRowView.swift
import SwiftUI
import AppKit

struct FileRowView: View {
    let job: ConversionJob

    var body: some View {
        HStack(spacing: 12) {
            fileIcon
            Text(job.sourceURL.lastPathComponent)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            statusView
        }
        .padding(.vertical, 4)
    }

    private var fileIcon: some View {
        Image(systemName: iconName)
            .foregroundStyle(.secondary)
            .frame(width: 20)
    }

    private var iconName: String {
        switch job.sourceURL.pathExtension.lowercased() {
        case "pdf":  return "doc.richtext"
        case "pptx": return "rectangle.on.rectangle"
        case "ods":  return "tablecells"
        default:     return "doc"
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch job.status {
        case .pending:
            Text("Pending")
                .foregroundStyle(.secondary)
                .font(.caption)
        case .converting:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Converting…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .done:
            HStack(spacing: 8) {
                Label("Done", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
                Button("Reveal") {
                    if let url = job.outputURL {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
        case .failed:
            Label("Failed", systemImage: "xmark.circle.fill")
                .foregroundStyle(.red)
                .font(.caption)
                .help(job.errorMessage ?? "Unknown error")
        }
    }
}
```

- [ ] **Step 4: Write TimeoutAlertView.swift**

```swift
// present2md/UI/TimeoutAlertView.swift
import SwiftUI

struct TimeoutAlertView: View {
    let jobID: UUID
    @EnvironmentObject var coordinator: ConversionCoordinator

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
            Text("Conversion is taking longer than expected.")
                .font(.headline)
            Text("Continue waiting or cancel this file?")
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Button("Cancel Conversion") {
                    coordinator.cancelJob(id: jobID)
                }
                .buttonStyle(.bordered)
                Button("Keep Waiting") {
                    coordinator.continueJob(id: jobID)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(32)
        .frame(minWidth: 320)
    }
}
```

- [ ] **Step 5: Build in Xcode and verify no compile errors**

In Xcode: `Cmd+B`

Expected: `Build Succeeded`

- [ ] **Step 6: Run the app and test golden path**

In Xcode: `Cmd+R`

1. Click Browse — verify file picker opens with only PDF/PPTX/ODS selectable
2. Select `Tests/Fixtures/sample.pptx` — verify row appears and converts to Done
3. Click Reveal — verify Finder opens to the `.md` file
4. Open the `.md` file — verify it contains "Slide One Title" and "Slide Two Title"
5. Drag `Tests/Fixtures/sample.ods` onto the list — verify it converts successfully
6. Click Clear Completed — verify all rows disappear

- [ ] **Step 7: Commit**

```bash
git add present2md/UI/
git commit -m "feat: add SwiftUI UI components (FileListView, FileRowView, EmptyStateView, TimeoutAlertView)"
```

---

## Task 15: Final Polish + Full Test Run

- [ ] **Step 1: Run full test suite**

```bash
swift test 2>&1
```

Expected: all unit and integration tests pass. Performance tests skip if fixtures absent.

- [ ] **Step 2: Run performance tests**

```bash
bash scripts/download_test_fixtures.sh
swift test --filter PerformanceTests 2>&1
```

Expected: both tests pass in under 60 seconds.

- [ ] **Step 3: Set minimum deployment target in Xcode**

In Xcode project settings → Deployment Info → macOS Deployment Target: `13.0`

- [ ] **Step 4: Archive for distribution check**

In Xcode: Product → Archive. Verify archive succeeds with no warnings about missing entitlements.

- [ ] **Step 5: Final commit and push**

```bash
git add -A
git commit -m "chore: final polish, ensure all tests pass and app builds for distribution"
git push origin main
```

---

## Summary

| Task | Deliverable |
|---|---|
| 1 | Swift package scaffold |
| 2 | Data models |
| 3 | FilenameConverter + 20 unit tests |
| 4 | FileConverter protocol + stubs |
| 5 | MarkdownSerializer + 10 unit tests |
| 6 | Test fixture generator script |
| 7 | PPTXConverter + 6 unit tests |
| 8 | ODSConverter + 6 unit tests |
| 9 | PDFConverter + 4 unit tests |
| 10 | ConversionCoordinator |
| 11 | 5 integration tests |
| 12 | Performance tests + download script |
| 13 | App entry point + ContentView |
| 14 | SwiftUI UI components |
| 15 | Final polish + full test run |
