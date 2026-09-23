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

  @available(iOS 17.0, *)
  func testShortcutDestinationCatalogFiltersWalletsBySelectedSpace() {
    let catalog = ShortcutDestinationCatalog(
      spaces: [
        ShortcutDestinationSpace(id: "personal", name: "Personal", isPortfolio: false),
        ShortcutDestinationSpace(id: "space-1", name: "Familia", isPortfolio: false),
        ShortcutDestinationSpace(id: "space-2", name: "旅行", isPortfolio: true),
      ],
      wallets: [
        ShortcutDestinationWallet(
          id: "wallet-personal",
          name: "Cash",
          spaceId: "personal",
          currency: "USD"
        ),
        ShortcutDestinationWallet(
          id: "wallet-family",
          name: "共同",
          spaceId: "space-1",
          currency: "JPY"
        ),
        ShortcutDestinationWallet(
          id: "wallet-travel",
          name: "Viaggi",
          spaceId: "space-2",
          currency: "EUR"
        ),
      ]
    )

    XCTAssertTrue(catalog.wallets(for: nil).isEmpty)
    XCTAssertEqual(catalog.wallets(for: "space-1").map(\.id), ["wallet-family"])
    XCTAssertEqual(catalog.wallets(for: "space-2").map(\.id), ["wallet-travel"])
  }

  @available(iOS 17.0, *)
  func testShortcutDestinationCatalogDropsInvalidAndOrphanedEntries() {
    let catalog = ShortcutDestinationCatalog(
      spaces: [
        ShortcutDestinationSpace(id: "personal", name: "Personal", isPortfolio: true),
        ShortcutDestinationSpace(id: " ", name: "Invalid", isPortfolio: false),
      ],
      wallets: [
        ShortcutDestinationWallet(
          id: "wallet-valid",
          name: "Main",
          spaceId: "personal",
          currency: "usd"
        ),
        ShortcutDestinationWallet(
          id: "wallet-orphan",
          name: "Old",
          spaceId: "deleted-space",
          currency: "EUR"
        ),
        ShortcutDestinationWallet(
          id: "wallet-invalid-currency",
          name: "Broken",
          spaceId: "personal",
          currency: "US"
        ),
      ]
    )

    XCTAssertEqual(catalog.spaces.map(\.id), ["personal"])
    XCTAssertFalse(catalog.spaces[0].isPortfolio)
    XCTAssertEqual(catalog.wallets.map(\.id), ["wallet-valid"])
    XCTAssertEqual(catalog.wallets.first?.currency, "USD")
  }

  @available(iOS 17.0, *)
  func testSelectedShortcutDestinationOverridesLegacyConfiguration() throws {
    let destination = try resolveNotificationShortcutDestination(
      selectedSpace: ShortcutDestinationSpace(
        id: "space-2",
        name: "旅行",
        isPortfolio: true
      ),
      selectedWallet: ShortcutDestinationWallet(
        id: "wallet-travel",
        name: "Viaggi",
        spaceId: "space-2",
        currency: "EUR"
      ),
      fallbackScope: SiriShortcutScopeResolution(
        householdId: "space-1",
        isPortfolio: false
      ),
      fallbackAccountId: "wallet-family"
    )

    XCTAssertEqual(destination.householdId, "space-2")
    XCTAssertTrue(destination.isPortfolio)
    XCTAssertEqual(destination.accountId, "wallet-travel")
  }

  @available(iOS 17.0, *)
  func testSelectingSpaceWithoutWalletDoesNotReuseLegacyWallet() throws {
    let destination = try resolveNotificationShortcutDestination(
      selectedSpace: ShortcutDestinationSpace(
        id: "space-2",
        name: "旅行",
        isPortfolio: true
      ),
      selectedWallet: nil,
      fallbackScope: SiriShortcutScopeResolution(
        householdId: "space-1",
        isPortfolio: false
      ),
      fallbackAccountId: "wallet-family"
    )

    XCTAssertEqual(destination.householdId, "space-2")
    XCTAssertNil(destination.accountId)
  }

  @available(iOS 17.0, *)
  func testWalletFromAnotherSelectedSpaceIsRejected() {
    XCTAssertThrowsError(
      try resolveNotificationShortcutDestination(
        selectedSpace: ShortcutDestinationSpace(
          id: "space-1",
          name: "Familia",
          isPortfolio: false
        ),
        selectedWallet: ShortcutDestinationWallet(
          id: "wallet-travel",
          name: "Viaggi",
          spaceId: "space-2",
          currency: "EUR"
        ),
        fallbackScope: nil,
        fallbackAccountId: nil
      )
    )
  }

  @available(iOS 17.0, *)
  func testWalletWithoutSelectedSpaceIsRejected() {
    XCTAssertThrowsError(
      try resolveNotificationShortcutDestination(
        selectedSpace: nil,
        selectedWallet: ShortcutDestinationWallet(
          id: "wallet-travel",
          name: "Viaggi",
          spaceId: "space-2",
          currency: "EUR"
        ),
        fallbackScope: SiriShortcutScopeResolution(
          householdId: "space-1",
          isPortfolio: false
        ),
        fallbackAccountId: "wallet-family"
      )
    )
  }

  @available(iOS 17.0, *)
  func testLegacyConfigurationRemainsTheFallback() throws {
    let destination = try resolveNotificationShortcutDestination(
      selectedSpace: nil,
      selectedWallet: nil,
      fallbackScope: SiriShortcutScopeResolution(
        householdId: "space-1",
        isPortfolio: false
      ),
      fallbackAccountId: "wallet-family"
    )

    XCTAssertEqual(destination.householdId, "space-1")
    XCTAssertFalse(destination.isPortfolio)
    XCTAssertEqual(destination.accountId, "wallet-family")
  }

}
