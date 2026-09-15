import XCTest
@testable import AppleFleetsCLI

final class RunSummaryTests: XCTestCase {
    func testDerivedMetrics() {
        let run = RunSummary.demo
        XCTAssertEqual(run.distanceKilometers, 10.24, accuracy: 0.001)
        XCTAssertTrue((130...160).contains(run.averageHeartRate ?? 0))
        XCTAssertEqual(run.splits.count, 10)
        XCTAssertTrue(run.paceText.contains("'"))
    }

    func testRoundTripMatchesIPhoneEncoding() throws {
        let data = try JSONEncoder().encode(RunSummary.demo)
        let decoded = try JSONDecoder().decode(RunSummary.self, from: data)
        XCTAssertEqual(decoded, .demo)
    }
}
