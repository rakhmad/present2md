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
