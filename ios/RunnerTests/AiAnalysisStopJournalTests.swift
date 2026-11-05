import XCTest
@testable import Runner

final class AiAnalysisStopJournalTests: XCTestCase {
  func testAllOutcomesMapToExactlyFourPresentationStates() {
    XCTAssertEqual(AiAnalysisPhase(outcome: nil), .loading)
    XCTAssertEqual(AiAnalysisPhase(outcome: "queued"), .success)
    XCTAssertEqual(AiAnalysisPhase(outcome: "review"), .success)
    XCTAssertEqual(AiAnalysisPhase(outcome: "needsInput"), .confirmation)
    XCTAssertEqual(AiAnalysisPhase(outcome: "error"), .error)
    XCTAssertEqual(AiAnalysisPhase(outcome: "paused"), .error)
    XCTAssertEqual(AiAnalysisPhase.success.visibleDuration, 5)
    XCTAssertNil(AiAnalysisPhase.error.visibleDuration)
    XCTAssertNil(AiAnalysisPhase.confirmation.visibleDuration)
  }
  func testStopSurvivesReopenAndAcknowledgementDoesNotLoseOtherAttempts() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let journal = AiAnalysisStopJournal(directory: root)
    try journal.record(id: "first", captureId: "capture", userId: "owner")
    try AiAnalysisStopJournal(directory: root).record(id: "second", captureId: "capture", userId: "owner")
    let reopened = AiAnalysisStopJournal(directory: root)
    XCTAssertEqual(Set(try reopened.pending().compactMap { $0["id"] }), ["first", "second"])
    try reopened.acknowledge("first")
    try reopened.acknowledge("first")
    XCTAssertEqual(try journal.pending(), [["id": "second", "captureId": "capture", "userId": "owner"]])
  }

  func testMalformedStopCannotBeAcknowledgedAsAnEmptyJournal() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let journal = AiAnalysisStopJournal(directory: root)
    XCTAssertThrowsError(try journal.record(id: "", captureId: "capture", userId: "owner"))
    try journal.record(id: "attempt", captureId: "capture", userId: "owner")
    let url = try XCTUnwrap(FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil).first)
    try Data("invalid".utf8).write(to: url)
    XCTAssertThrowsError(try journal.pending())
  }
}
