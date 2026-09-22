import Flutter
import UIKit
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {

  func testNotificationShortcutPayloadMapsVisibleFields() {
    let notification = NotificationShortcutCapturePayload.makeNotification(
      title: "Card purchase",
      subtitle: "Coffee Shop",
      message: "USD 12.50 completed",
      sourceAppName: "Example Bank"
    )

    XCTAssertEqual(notification?["packageName"] as? String, "ios.notification.shortcut")
    XCTAssertEqual(notification?["title"] as? String, "Card purchase")
    XCTAssertEqual(notification?["subText"] as? String, "Coffee Shop")
    XCTAssertEqual(notification?["text"] as? String, "USD 12.50 completed")
    XCTAssertEqual(notification?["sourceAppLabel"] as? String, "Example Bank")
  }

  func testNotificationShortcutPayloadRejectsEmptyContent() {
    XCTAssertNil(
      NotificationShortcutCapturePayload.makeNotification(
        title: " ",
        subtitle: nil,
        message: "\n",
        sourceAppName: "Example Bank"
      )
    )
  }

  func testNotificationShortcutIdempotencyIsStableWithinMinute() {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let first = NotificationShortcutCapturePayload.makeIdempotencyKey(
      userId: "user-1",
      scopeKey: "personal",
      title: "Purchase",
      subtitle: nil,
      message: "USD 12.50 at Coffee Shop",
      sourceAppName: "Example Bank",
      date: date
    )
    let second = NotificationShortcutCapturePayload.makeIdempotencyKey(
      userId: "user-1",
      scopeKey: "personal",
      title: " purchase ",
      subtitle: nil,
      message: "usd 12.50 at coffee shop",
      sourceAppName: "example bank",
      date: date.addingTimeInterval(30)
    )

    XCTAssertEqual(first, second)
  }

}
