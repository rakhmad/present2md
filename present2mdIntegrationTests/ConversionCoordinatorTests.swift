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
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".pptx")
        try FileManager.default.copyItem(at: pptxFixture, to: tmp)
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

        if let outputURL = coordinator.jobs.first?.outputURL {
            try? FileManager.default.removeItem(at: outputURL)
        }
        coordinator.clearCompleted()
        XCTAssertTrue(coordinator.jobs.isEmpty)
    }
}
