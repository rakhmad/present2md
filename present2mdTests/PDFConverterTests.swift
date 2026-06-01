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

    // PDFKit always writes ≥1 page; an empty (0-byte) file is the closest
    // real-world trigger for "no content to convert" → unreadableFile.
    func testEmptyPDFThrows() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".pdf")
        try Data().write(to: url)
        XCTAssertThrowsError(try PDFConverter().convert(url: url)) { error in
            XCTAssertEqual(error as? ConverterError, .unreadableFile)
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
