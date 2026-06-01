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
