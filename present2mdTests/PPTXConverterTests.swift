import XCTest
@testable import present2mdCore

final class PPTXConverterTests: XCTestCase {

    private var fixtureURL: URL {
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
