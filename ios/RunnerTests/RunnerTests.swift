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

  func testWalletCaptureInProgressIsRetryableAndMalformedSuccessIsUnconfirmed() {
    XCTAssertTrue(WalletCaptureRetryPolicy.isRetryable(statusCode: 409,
      responseBody: Data(#"{"code":"REQUEST_IN_PROGRESS"}"#.utf8)))
    XCTAssertFalse(WalletCaptureRetryPolicy.isRetryable(statusCode: 409,
      responseBody: Data(#"{"code":"DUPLICATE_REQUEST"}"#.utf8)))
    for body in ["not-json", #"{"success":true}"#, #"{"success":false,"ignored":true}"#] {
      XCTAssertFalse(WalletCaptureRetryPolicy.isConfirmedSuccess(responseBody: Data(body.utf8)))
    }
    for body in [#"{"success":true,"ignored":true}"#, #"{"success":true,"duplicate":true}"#,
                 #"{"success":true,"data":{"id":"saved-id"}}"#] {
      XCTAssertTrue(WalletCaptureRetryPolicy.isConfirmedSuccess(responseBody: Data(body.utf8)))
    }
  }

  func testNotificationCaptureCommitsBeforeSendAndRetainsRetryableFailures() async {
    for error in [SiriShortcutIntentError.networkFailure, .missingSession, .retryableFailure(statusCode: 409), .retryableFailure(statusCode: 503)] {
      var queued = false
      var finished = false
      do {
        _ = try await NotificationShortcutCaptureDispatcher.submit(
          enqueue: { queued = true; return true },
          send: { XCTAssertTrue(queued); throw error },
          finish: { finished = true }
        )
        XCTFail("Expected retryable error")
      } catch {}
      XCTAssertTrue(queued)
      XCTAssertFalse(finished)
    }
  }

  func testNotificationCapturePersistenceFailurePreventsRemoteSave() async {
    var sent = false
    do {
      _ = try await NotificationShortcutCaptureDispatcher.submit(
        enqueue: { false }, send: { sent = true; return (false, false) }, finish: {}
      )
      XCTFail("Expected persistence failure")
    } catch {}
    XCTAssertFalse(sent)
  }

  func testNotificationCaptureRemovesOnlyConfirmedOrTerminalRequests() async throws {
    var finished = false
    let result = try await NotificationShortcutCaptureDispatcher.submit(
      enqueue: { true }, send: { (false, true) }, finish: { finished = true }
    )
    XCTAssertTrue(result.isIgnored)
    XCTAssertTrue(finished)
    finished = false
    do {
      _ = try await NotificationShortcutCaptureDispatcher.submit(
        enqueue: { true }, send: { throw SiriShortcutIntentError.invalidInput },
        finish: { finished = true }
      )
      XCTFail("Expected terminal rejection")
    } catch {}
    XCTAssertTrue(finished)
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

  private let siriSpaceId = "11111111-1111-4111-8111-111111111111"
  private let siriWalletId = "22222222-2222-4222-8222-222222222222"
  private let siriCapturedAt = Date(timeIntervalSince1970: 1_800_000_000)

  private func siriItem(currency: String = "USD", household: Bool = false) -> [String: Any] {
    [
      "type": "expense", "amount": 20.0, "category": "groceries", "currency": currency,
      "date": "2026-10-05", "merchant": "Tesco", "description": "Lunch",
      "explicitFields": ["amount", "currency", "merchant", "date", "transactionTime", "walletId"],
      "transactionTime": "13:05:00",
      "destination": ["householdId": household ? siriSpaceId as Any : NSNull(),
                      "isPortfolio": household, "accountId": siriWalletId, "accountCurrency": currency]
    ]
  }

  private func siriReady(_ items: [[String: Any]]) -> [String: Any] {
    ["success": true, "data": ["interactiveVersion": 1, "requireCorrection": false,
      "items": items, "preferredTimezone": "Europe/Dublin"]]
  }

  func testSiriPreservesNativeFieldsAndEachAuthorizedDestination() throws {
    var income = siriItem(currency: "JPY", household: true)
    income["type"] = "income"
    income["merchant"] = "給与"
    income["merchant_id"] = siriSpaceId
    income["merchant_structured_name"] = "会社"
    income["payerUserId"] = "33333333-3333-4333-8333-333333333333"
    income["customSplits"] = ["splitType": "equal"]
    let prepared = try SiriTransactionCapture.prepare(items: [siriItem(), income],
      userId: "user-1", captureKey: "capture", preferredTimezone: "Europe/Dublin", capturedAt: siriCapturedAt)
    XCTAssertEqual(prepared.map(\.endpoint), ["save-expense", "save-income"])
    XCTAssertEqual(prepared.map(\.idempotencyKey), ["capture-0", "capture-1"])
    XCTAssertNil(prepared[0].body["householdId"])
    XCTAssertEqual(prepared[1].body["householdId"] as? String, siriSpaceId)
    XCTAssertEqual(prepared[1].body["accountId"] as? String, siriWalletId)
    XCTAssertEqual(prepared[1].body["currency"] as? String, "JPY")
    XCTAssertEqual(prepared[1].body["merchant"] as? String, "給与")
    XCTAssertEqual(prepared[1].body["merchantId"] as? String, siriSpaceId)
    XCTAssertEqual(prepared[1].body["merchantStructuredName"] as? String, "会社")
    XCTAssertEqual(prepared[1].body["date"] as? String, "2026-10-05")
    XCTAssertEqual(prepared[1].body["clientCreatedAt"] as? String, "2026-10-05T12:05:00Z")
    XCTAssertNotNil(prepared[1].body["payerUserId"])
    XCTAssertNotNil(prepared[1].body["customSplits"])
    XCTAssertEqual(prepared[0].body["categoryAlreadyResolved"] as? Bool, true)
  }

  func testSiriMerchantBlockerIsTrueOnlyAndSurvivesDurablePlanRoundtrip() throws {
    for type in ["expense", "income"] {
      for marker: Any in [true, false, NSNull(), "true"] {
        var item = siriItem()
        item["type"] = type
        item["merchant"] = "原文の相手"
        if !(marker is NSNull) { item["merchant_auto_resolution_blocked"] = marker }
        let prepared = try SiriTransactionCapture.prepare(items: [item],
          userId: "user-1", captureKey: "capture", preferredTimezone: "UTC", capturedAt: siriCapturedAt)
        let blocked = (marker as? Bool) == true
        XCTAssertEqual(prepared[0].body["merchantAutoResolutionBlocked"] as? Bool, blocked ? true : nil)
        var records: [[String: Any]] = []
        XCTAssertTrue(SiriTransactionCapture.enqueue(prepared, userId: "user-1", load: { records }, save: { records = $0; return true }))
        let data = try JSONSerialization.data(withJSONObject: records)
        let restored = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        let body = try XCTUnwrap(restored[0]["body"] as? [String: Any])
        XCTAssertEqual(body["merchantAutoResolutionBlocked"] as? Bool, blocked ? true : nil)
        XCTAssertEqual(body["merchant"] as? String, "原文の相手")
        XCTAssertEqual(body["amount"] as? Double, 20)
        XCTAssertEqual(body["currency"] as? String, "USD")
        XCTAssertEqual(body["date"] as? String, "2026-10-05")
        XCTAssertEqual(body["clientCreatedAt"] as? String, "2026-10-05T13:05:00Z")
        XCTAssertEqual(restored[0]["endpoint"] as? String, type == "income" ? "save-income" : "save-expense")
      }
    }
  }

  private func siriDefaultsPayload(spaceId: String = "personal", currency: String = "EUR") -> [String: Any] {
    ["version": 1, "userId": "user-1", "currency": currency, "spaceId": spaceId,
     "isPortfolio": false, "accountId": siriWalletId, "walletsReady": true]
  }

  func testSiriUsesAppSelectionsWithoutAnotherQuestionWhenFieldsAreOmitted() async throws {
    let defaults = try XCTUnwrap(SiriTransactionDefaults.resolve(
      siriDefaultsPayload(spaceId: siriSpaceId), expectedUserId: "user-1"))
    let source = "午餐20，在乐购"
    let body = try SiriTransactionCapture.analysisBody(text: source, userId: "user-1",
      typeHint: "expense", defaults: defaults)
    var item = siriItem(currency: "EUR", household: true)
    item["explicitFields"] = ["amount", "merchant"]
    item.removeValue(forKey: "transactionTime")
    var destination = item["destination"] as! [String: Any]
    destination["isPortfolio"] = false
    item["destination"] = destination
    var analyses = 0
    let captures = try await SiriTransactionCapture.resolve(body: body, capturedAt: siriCapturedAt,
      analyze: { request in
        analyses += 1
        XCTAssertEqual(request["text"] as? String, source)
        XCTAssertEqual(request["currency"] as? String, "EUR")
        XCTAssertEqual(request["householdId"] as? String, self.siriSpaceId)
        XCTAssertEqual(request["accountId"] as? String, self.siriWalletId)
        XCTAssertNil(request["explicitFields"])
        return self.siriReady([item])
      }, clarify: { _ in XCTFail("Omitted destination fields already have app defaults"); return "" })
    XCTAssertEqual(analyses, 1)
    XCTAssertEqual(captures[0].body["currency"] as? String, "EUR")
    XCTAssertEqual(captures[0].body["householdId"] as? String, siriSpaceId)
    XCTAssertEqual(captures[0].body["accountId"] as? String, siriWalletId)
  }

  func testSiriSpokenOverridesRemainAuthoritativeOverAppDefaults() async throws {
    let defaults = SiriTransactionDefaults.resolve(siriDefaultsPayload(spaceId: siriSpaceId), expectedUserId: "user-1")
    let body = try SiriTransactionCapture.analysisBody(text: "Personal, 20 US dollars at Tesco",
      userId: "user-1", typeHint: "expense", defaults: defaults)
    let captures = try await SiriTransactionCapture.resolve(body: body, capturedAt: siriCapturedAt,
      analyze: { _ in self.siriReady([self.siriItem()]) },
      clarify: { _ in XCTFail("Verified explicit overrides need no extra confirmation"); return "" })
    XCTAssertEqual(captures[0].body["currency"] as? String, "USD")
    XCTAssertNil(captures[0].body["householdId"])
  }

  func testSiriShortcutOverridesNeverReuseAnIncompatibleDefaultWallet() throws {
    let defaults = SiriTransactionDefaults.resolve(siriDefaultsPayload(spaceId: siriSpaceId), expectedUserId: "user-1")
    let currency = try SiriTransactionCapture.analysisBody(text: "déjeuner 20", userId: "user-1",
      typeHint: "expense", defaults: defaults, currencyCode: "USD")
    XCTAssertEqual(currency["currency"] as? String, "USD")
    XCTAssertEqual(currency["householdId"] as? String, siriSpaceId)
    XCTAssertNil(currency["accountId"])
    let personal = try SiriTransactionCapture.analysisBody(text: "20 almuerzo", userId: "user-1",
      typeHint: "expense", defaults: defaults, spaceId: "personal")
    XCTAssertNil(personal["householdId"])
    XCTAssertNil(personal["isPortfolio"])
    XCTAssertNil(personal["accountId"])
    XCTAssertEqual(personal["currency"] as? String, "EUR")
  }

  func testSiriRetainsCachedWalletDuringRefreshOnlyForTheSameActorSpaceAndCurrency() throws {
    let previous = SiriTransactionDefaults.resolve(siriDefaultsPayload(), expectedUserId: "user-1")
    var refreshing = siriDefaultsPayload()
    refreshing.removeValue(forKey: "accountId")
    refreshing["walletsReady"] = false
    XCTAssertEqual(SiriTransactionDefaults.resolve(refreshing, expectedUserId: "user-1", previous: previous)?.accountId, siriWalletId)
    for field in ["currency", "spaceId", "userId"] {
      var changed = refreshing
      changed[field] = field == "currency" ? "USD" : field == "spaceId" ? siriSpaceId : "user-2"
      XCTAssertNil(SiriTransactionDefaults.resolve(changed, expectedUserId: changed["userId"] as! String, previous: previous)?.accountId)
    }
    refreshing["walletsReady"] = true
    XCTAssertNil(SiriTransactionDefaults.resolve(refreshing, expectedUserId: "user-1", previous: previous)?.accountId)
  }

  func testSiriDefaultsSurviveColdReadAndRejectAnotherActorOrMalformedSnapshot() throws {
    let suiteName = "SiriDefaultsTests-" + UUID().uuidString
    let store = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defer { store.removePersistentDomain(forName: suiteName) }
    let snapshot = try XCTUnwrap(SiriTransactionDefaults.resolve(siriDefaultsPayload(), expectedUserId: "user-1"))
    store.set(snapshot.payload, forKey: "siri_transaction_defaults")
    let coldStore = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    XCTAssertEqual(SiriTransactionDefaults.load(expectedUserId: "user-1", defaults: coldStore)?.accountId, siriWalletId)
    XCTAssertNil(SiriTransactionDefaults.load(expectedUserId: "user-2", defaults: coldStore))
    for field in ["version", "currency", "spaceId", "accountId"] {
      var malformed = siriDefaultsPayload()
      malformed[field] = "invalid"
      XCTAssertNil(SiriTransactionDefaults.resolve(malformed, expectedUserId: "user-1"))
    }
    let body = try SiriTransactionCapture.analysisBody(text: "20 lunch", userId: "user-2", typeHint: "expense", defaults: snapshot)
    XCTAssertNil(body["currency"])
    XCTAssertNil(body["accountId"])
  }

  func testSiriRejectsIncompleteAndConflictingDestinationsWithoutPartialPreparation() {
    for field in ["currency", "date", "explicitFields", "destination"] {
      var invalid = siriItem()
      invalid.removeValue(forKey: field)
      XCTAssertThrowsError(try SiriTransactionCapture.prepare(items: [siriItem(), invalid],
        userId: "user-1", captureKey: "capture", preferredTimezone: "UTC", capturedAt: siriCapturedAt))
    }
    var conflict = siriItem()
    var destination = conflict["destination"] as! [String: Any]
    destination["accountCurrency"] = "EUR"
    conflict["destination"] = destination
    XCTAssertThrowsError(try SiriTransactionCapture.prepare(items: [conflict],
      userId: "user-1", captureKey: "capture", preferredTimezone: "UTC", capturedAt: siriCapturedAt))
  }

  func testSiriPreservesRecurringIntentAndDoesNotInventPaidTime() throws {
    var item = siriItem()
    item.removeValue(forKey: "transactionTime")
    item["isRecurring"] = true
    item["recurrence_rule"] = ["frequency": "monthly", "anchor_date": "2026-10-05"]
    let prepared = try SiriTransactionCapture.prepare(items: [item], userId: "user-1",
      captureKey: "capture", preferredTimezone: "UTC", capturedAt: siriCapturedAt)
    XCTAssertEqual(prepared[0].body["isRecurring"] as? Bool, true)
    XCTAssertNotNil(prepared[0].body["recurrence_rule"])
    XCTAssertEqual(prepared[0].body["clientCreatedAt"] as? String, ISO8601DateFormatter().string(from: siriCapturedAt))
  }

  func testSiriClockPreservesMidnightSecondsAndFixedOffset() throws {
    XCTAssertEqual(try SiriTransactionCapture.createdAt(date: "2026-10-05", time: "00:00:00", timezone: "UTC+08:00"), "2026-10-04T16:00:00Z")
    XCTAssertEqual(try SiriTransactionCapture.createdAt(date: "2026-10-05", time: "21:30:07", timezone: "America/New_York"), "2026-10-06T01:30:07Z")
    XCTAssertThrowsError(try SiriTransactionCapture.createdAt(date: "2026-10-05", time: "25:00:00", timezone: "UTC"))
  }

  func testSiriClockRequestsClarificationForDaylightSavingGapsAndRepeats() {
    for (date, reason) in [("2026-03-08", "nonexistent_wall_time"), ("2026-11-01", "ambiguous_wall_time")] {
      let time = reason == "nonexistent_wall_time" ? "02:30:00" : "01:30:00"
      XCTAssertThrowsError(try SiriTransactionCapture.createdAt(date: date, time: time, timezone: "America/New_York", itemIndex: 2)) { error in
        XCTAssertEqual((error as? SiriTransactionClockIssue)?.reason, reason)
        XCTAssertEqual((error as? SiriTransactionClockIssue)?.itemIndex, 2)
      }
    }
  }

  func testSiriClarificationKeepsOriginalMultilingualSourceAndAcceptedAnswers() async throws {
    let source = "昨日、家族のスペースで財布から昼食に20ドル、テスコで"
    var calls = 0
    let captures = try await SiriTransactionCapture.resolve(body: ["userId": "user-1", "text": source],
      capturedAt: siriCapturedAt,
      analyze: { request in
        XCTAssertEqual(request["text"] as? String, source)
        let interactive = request["interactive"] as! [String: Any]
        XCTAssertEqual(interactive["version"] as? Int, 1)
        let answers = interactive["answers"] as! [[String: String]]
        calls += 1
        if calls == 1 {
          XCTAssertTrue(answers.isEmpty)
          return ["success": true, "data": ["interactiveVersion": 1, "requireCorrection": true,
            "items": [self.siriItem()], "correction": ["question": "どの通貨ですか？", "choices": ["USD", "CAD"], "allowCustomResponse": true]]]
        }
        XCTAssertEqual(answers, [["question": "どの通貨ですか？", "answer": "USD"]])
        return self.siriReady([self.siriItem()])
      },
      clarify: { prompt in
        XCTAssertTrue(prompt.contains("USD; CAD"))
        return "USD"
      })
    XCTAssertEqual(calls, 2)
    XCTAssertEqual(captures.count, 1)
  }

  func testSiriDoesNotSaveLegacyOrUnverifiedAnalysis() async throws {
    for response: [String: Any] in [
      ["success": true, "data": ["items": [siriItem()]]],
      ["success": false, "data": ["interactiveVersion": 1, "requireCorrection": false, "items": [siriItem()]]],
      ["success": true, "data": ["interactiveVersion": 1, "requireCorrection": true, "items": [siriItem()]]]
    ] {
      do {
        _ = try await SiriTransactionCapture.resolve(body: ["userId": "user-1", "text": "20 for lunch"],
          capturedAt: siriCapturedAt, analyze: { _ in response }, clarify: { _ in XCTFail("Invalid question"); return "USD" })
        XCTFail("Unverified analysis must not prepare a save")
      } catch { XCTAssertTrue(error is SiriShortcutIntentError) }
    }
  }

  func testSiriEqualItemsHaveDistinctStableRetryIdentities() async throws {
    var identities: [[String]] = []
    for _ in 0..<2 {
      let prepared = try await SiriTransactionCapture.resolve(body: ["userId": "user-1", "text": "午餐20美元，另一次午餐20美元"],
        capturedAt: siriCapturedAt, captureKey: "original-capture",
        analyze: { _ in self.siriReady([self.siriItem(), self.siriItem()]) },
        clarify: { _ in XCTFail("Ready input"); return "" })
      identities.append(prepared.map(\.idempotencyKey))
    }
    XCTAssertEqual(identities[0], identities[1])
    XCTAssertNotEqual(identities[0][0], identities[0][1])
    let separate = try await SiriTransactionCapture.resolve(body: ["userId": "user-1", "text": "午餐20美元，另一次午餐20美元"],
      capturedAt: siriCapturedAt, analyze: { _ in self.siriReady([self.siriItem(), self.siriItem()]) },
      clarify: { _ in XCTFail("Ready input"); return "" })
    XCTAssertNotEqual(separate.map(\.idempotencyKey), identities[0])
  }

  func testSiriPersistsCompletePlanBeforeAnyDispatchAndRetainsOfflineItem() async throws {
    let captures = try SiriTransactionCapture.prepare(items: [siriItem(), siriItem()], userId: "user-1",
      captureKey: "capture", preferredTimezone: "UTC", capturedAt: siriCapturedAt)
    var records: [[String: Any]] = []
    var attempts = 0
    let outcome = try await SiriTransactionCapture.dispatch(captures,
      enqueue: { SiriTransactionCapture.enqueue(captures, userId: "user-1", load: { records }, save: { records = $0; return true }) },
      submit: { capture in
        attempts += 1
        if attempts == 1 { XCTAssertEqual(records.count, 2) }
        XCTAssertEqual(capture.body["idempotencyKey"] as? String, capture.idempotencyKey)
        if attempts == 2 { throw SiriShortcutIntentError.networkFailure }
      },
      finish: { key in records.removeAll { ($0["idempotencyKey"] as? String) == key } })
    XCTAssertEqual(outcome.saved, 1)
    XCTAssertEqual(outcome.queued, 1)
    XCTAssertEqual(records.count, 1)
    XCTAssertEqual(records[0]["idempotencyKey"] as? String, "capture-1")
    XCTAssertEqual(records[0]["userId"] as? String, "user-1")
    XCTAssertEqual(records[0]["endpoint"] as? String, "save-expense")
    let retry = records[0]["body"] as! [String: Any]
    XCTAssertTrue(NSDictionary(dictionary: retry).isEqual(to: captures[1].body))
  }

  func testSiriCannotDispatchAfterPersistenceFailureAndTerminalRejectionIsVisible() async throws {
    let captures = try SiriTransactionCapture.prepare(items: [siriItem()], userId: "user-1",
      captureKey: "capture", preferredTimezone: "UTC", capturedAt: siriCapturedAt)
    do {
      _ = try await SiriTransactionCapture.dispatch(captures, enqueue: { false },
        submit: { _ in XCTFail("No durable write") }, finish: { _ in XCTFail("No dispatch") })
      XCTFail("Must fail local save")
    } catch { XCTAssertTrue(error is SiriShortcutIntentError) }
    var finished: [String] = []
    let outcome = try await SiriTransactionCapture.dispatch(captures, enqueue: { true },
      submit: { _ in throw SiriShortcutIntentError.backendError(message: "Wallet is archived", code: "ACCOUNT_INVALID") },
      finish: { finished.append($0) })
    XCTAssertEqual(outcome.saved, 0)
    XCTAssertEqual(outcome.queued, 0)
    XCTAssertEqual(outcome.failures, ["Wallet is archived"])
    XCTAssertEqual(finished, ["capture-0"])
  }

  func testSiriQueueDeduplicatesAndRejectsAFullPlanAtomically() throws {
    let captures = try SiriTransactionCapture.prepare(items: [siriItem(), siriItem()], userId: "user-1",
      captureKey: "capture", preferredTimezone: "UTC", capturedAt: siriCapturedAt)
    var records: [[String: Any]] = []
    for _ in 0..<2 {
      XCTAssertTrue(SiriTransactionCapture.enqueue(captures, userId: "user-1", load: { records }, save: { records = $0; return true }))
    }
    XCTAssertEqual(records.count, 2)
    let full = Array(repeating: ["idempotencyKey": "old"], count: 99)
    XCTAssertFalse(SiriTransactionCapture.enqueue(captures, userId: "user-1", load: { full }, save: { _ in XCTFail("Partial plan"); return true }))
  }

}
