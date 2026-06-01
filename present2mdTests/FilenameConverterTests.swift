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
        XCTAssertEqual(result.count, 203) // 200 stem + ".md"
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
