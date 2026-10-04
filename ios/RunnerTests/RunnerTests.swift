import Flutter
import UIKit
import XCTest
import FirebaseCore
import firebase_messaging
@testable import Runner

class RunnerTests: XCTestCase {

  private func captureContext(expired: Bool = false, userId: String = "user-1") -> SiriShortcutAuthContext {
    SiriShortcutAuthContext(
      supabaseUrl: "https://example.supabase.co", supabaseAnonKey: "anon-key",
      accessToken: expired ? "expired-token" : "fresh-token", userId: userId,
      expiresAt: Int(Date().timeIntervalSince1970) + (expired ? -3600 : 3600)
    )
  }

  func testExpiredOnlineCaptureRefreshesThenSavesWithoutQueuing() async throws {
    var events: [String] = []
    let result = try await WalletCaptureOnlineDispatcher.submit(
      context: captureContext(expired: true),
      refresh: { force in
        XCTAssertFalse(force)
        events.append("refresh")
        return self.captureContext()
      },
      save: { context in
        XCTAssertEqual(context.accessToken, "fresh-token")
        events.append("save")
        return (false, false)
      }
    )
    XCTAssertEqual(events, ["refresh", "save"])
    XCTAssertFalse(result.isDuplicate)
  }

  func testFreshCaptureSavesWithoutRefresh() async throws {
    _ = try await WalletCaptureOnlineDispatcher.submit(
      context: captureContext(),
      refresh: { _ in XCTFail("Fresh token must not refresh"); return self.captureContext() },
      save: { _ in (false, false) }
    )
  }

  func testRejectedTokenRetriesOnlyOnceWithSameCapture() async throws {
    var attempts = 0
    var refreshes = 0
    let body: [String: Any] = ["idempotencyKey": "original-key", "merchant": "旅行", "amount": 24.1]
    var dispatchedBodies: [[String: Any]] = []
    do {
      _ = try await WalletCaptureOnlineDispatcher.submit(
        context: captureContext(),
        refresh: { force in
          XCTAssertTrue(force)
          refreshes += 1
          return self.captureContext()
        },
        save: { _ in
          attempts += 1
          dispatchedBodies.append(body)
          throw SiriShortcutIntentError.missingSession
        }
      )
      XCTFail("Persistent rejection must remain queueable")
    } catch let error as SiriShortcutIntentError {
      XCTAssertTrue(error.canQueueCapture)
    }
    XCTAssertEqual(attempts, 2)
    XCTAssertEqual(refreshes, 1)
    XCTAssertTrue(NSDictionary(dictionary: dispatchedBodies[0]).isEqual(to: dispatchedBodies[1]))
  }

  func testAuthRejectionRecoversWithCurrentSession() async throws {
    var attempts = 0
    _ = try await WalletCaptureOnlineDispatcher.submit(
      context: captureContext(),
      refresh: { force in XCTAssertTrue(force); return self.captureContext() },
      save: { _ in
        attempts += 1
        if attempts == 1 { throw SiriShortcutIntentError.missingSession }
        return (false, false)
      }
    )
    XCTAssertEqual(attempts, 2)
  }

  func testFailedRefreshRetainsQueueableFailureWithoutSending() async throws {
    do {
      _ = try await WalletCaptureOnlineDispatcher.submit(
        context: captureContext(expired: true),
        refresh: { _ in throw SiriShortcutIntentError.networkFailure },
        save: { _ in XCTFail("Cannot save without current credentials"); return (false, false) }
      )
      XCTFail("Offline refresh must fail")
    } catch let error as SiriShortcutIntentError {
      XCTAssertTrue(error.canQueueCapture)
    }
  }

  func testRefreshCannotDispatchAnotherUserOrExpiredSession() async throws {
    for candidate in [captureContext(userId: "user-2"), captureContext(expired: true)] {
      do {
        _ = try await WalletCaptureOnlineDispatcher.submit(
          context: captureContext(expired: true),
          refresh: { _ in candidate },
          save: { _ in XCTFail("Invalid refresh must not dispatch"); return (false, false) }
        )
        XCTFail("Invalid refresh must fail")
      } catch let error as SiriShortcutIntentError {
        XCTAssertTrue(error.canQueueCapture)
      }
    }
  }

  @MainActor
  func testColdEngineSessionRequestRetriesUntilDartHandlerIsReady() async throws {
    let context = captureContext()
    var attempts = 0
    let current: SiriShortcutAuthContext = try await withCheckedThrowingContinuation { continuation in
      let request = WalletCaptureSessionRequest(
        context: context, forceRefresh: false,
        invoke: { arguments, reply in
          XCTAssertEqual(arguments["userId"] as? String, "user-1")
          attempts += 1
          if attempts == 1 { return false }
          if attempts == 2 { reply(FlutterMethodNotImplemented) }
          else { reply(["accessToken": "fresh-token", "userId": "user-1", "expiresAt": context.expiresAt]) }
          return true
        },
        completion: { continuation.resume(with: $0) }
      )
      request.start()
    }
    XCTAssertEqual(current.userId, "user-1")
    XCTAssertEqual(attempts, 3)
  }

  @MainActor
  func testSessionRequestRejectsInvalidDartCredentialsAndRefreshErrors() async throws {
    let context = captureContext()
    let replies: [Any] = [
      ["accessToken": "fresh-token", "userId": "user-2", "expiresAt": context.expiresAt],
      ["accessToken": "fresh-token", "userId": "user-1", "expiresAt": 1],
      ["accessToken": "", "userId": "user-1", "expiresAt": context.expiresAt],
      FlutterError(code: "capture_session_unavailable", message: nil, details: nil),
      FlutterError(code: "error", message: "Offline", details: nil),
    ]
    for reply in replies {
      do {
        let _: SiriShortcutAuthContext = try await withCheckedThrowingContinuation { continuation in
          let request = WalletCaptureSessionRequest(
            context: context, forceRefresh: false,
            invoke: { _, completion in completion(reply); return true },
            completion: { continuation.resume(with: $0) }
          )
          request.start()
        }
        XCTFail("Invalid Dart credentials must remain queueable")
      } catch let error as SiriShortcutIntentError {
        XCTAssertTrue(error.canQueueCapture)
      }
    }
  }

  @MainActor
  func testSessionRequestTimeoutCompletesOnceAndIgnoresLateReply() async throws {
    var reply: FlutterResult?
    var completions = 0
    let completed = expectation(description: "bounded session request")
    let context = captureContext()
    let request = WalletCaptureSessionRequest(
      context: context, forceRefresh: false,
      invoke: { _, callback in reply = callback; return true }, timeout: 0.01,
      completion: { result in
        completions += 1
        if case .success = result { XCTFail("Unavailable Dart must time out") }
        completed.fulfill()
      }
    )
    request.start()
    await fulfillment(of: [completed], timeout: 1)
    reply?(["accessToken": "fresh-token", "userId": "user-1", "expiresAt": context.expiresAt])
    XCTAssertEqual(completions, 1)
  }

  func testSceneUsesTheEngineRegisteredAtApplicationLaunch() throws {
    let appDelegate = try XCTUnwrap(UIApplication.shared.delegate as? AppDelegate)
    let engine = try XCTUnwrap(appDelegate.flutterEngine)
    let controller = try XCTUnwrap(appDelegate.window?.rootViewController as? FlutterViewController)

    XCTAssertTrue(controller.engine === engine)
    XCTAssertTrue(engine.hasPlugin("FLTFirebaseMessagingPlugin"))
    XCTAssertTrue(engine.hasPlugin("AppLinksIosPlugin"))
  }

  func testFirebaseMessagingReceivesLaunchAndCompletesInitialMessageRead() throws {
    let appDelegate = try XCTUnwrap(UIApplication.shared.delegate as? AppDelegate)
    let engine = try XCTUnwrap(appDelegate.flutterEngine)
    let plugin = try XCTUnwrap(
      engine.valuePublished(byPlugin: "FLTFirebaseMessagingPlugin") as? FLTFirebaseMessagingPlugin
    )
    if FirebaseApp.app() == nil {
      FirebaseApp.configure()
    }
    let completed = expectation(description: "Firebase Messaging initialized at launch")

    // Without the launch callback, the plugin leaves this request pending forever.
    plugin.handle(FlutterMethodCall(methodName: "Messaging#getInitialMessage", arguments: nil)) { result in
      XCTAssertFalse(result is FlutterError)
      completed.fulfill()
    }
    wait(for: [completed], timeout: 2)
  }

  func testWalletCaptureRetainsTemporaryServerFailuresForRetry() {
    for statusCode in [408, 425, 429, 500, 502, 503, 504, 599] {
      XCTAssertTrue(WalletCaptureRetryPolicy.isRetryable(statusCode: statusCode))
    }
    for statusCode in [200, 400, 401, 403, 404, 409, 422] {
      XCTAssertFalse(WalletCaptureRetryPolicy.isRetryable(statusCode: statusCode))
    }
  }

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
