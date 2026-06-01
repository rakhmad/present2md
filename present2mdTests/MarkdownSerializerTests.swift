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
