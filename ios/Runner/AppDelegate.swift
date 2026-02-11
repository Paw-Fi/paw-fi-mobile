import UIKit
import Flutter
import AppIntents
import Foundation
import Security
import CryptoKit

private enum SiriShortcutChannel {
  static let name = "moneko/siri_shortcut_auth"
  static let syncAuthContext = "syncAuthContext"
  static let getStatus = "getStatus"
  static let clearAuthContext = "clearAuthContext"
}

private enum SiriShortcutKeys {
  static let appGroupId = "group.moneko.mobile"
  static let supabaseUrl = "siri_supabase_url"
  static let supabaseAnonKey = "siri_supabase_anon_key"

  static let keychainService = "com.moneko.mobile.siri-shortcut-auth"
  static let accessTokenAccount = "access_token"
  static let refreshTokenAccount = "refresh_token"
  static let userIdAccount = "user_id"
  static let expiresAtAccount = "expires_at"

  static let idempotencyHash = "siri_last_request_hash"
  static let idempotencyTimestamp = "siri_last_request_at"
}

private struct SiriShortcutScopeResolution {
  let householdId: String?
  let isPortfolio: Bool
}

private struct SiriShortcutAuthContext {
  let supabaseUrl: String
  let supabaseAnonKey: String
  let accessToken: String
  let refreshToken: String
  let userId: String
  let expiresAt: Int

  var isAccessTokenExpired: Bool {
    guard expiresAt > 0 else { return false }
    let now = Int(Date().timeIntervalSince1970)
    return now >= max(0, expiresAt - 30)
  }

  static func load() -> SiriShortcutAuthContext? {
    guard let defaults = UserDefaults(suiteName: SiriShortcutKeys.appGroupId) else {
      return nil
    }

    let supabaseUrl = (defaults.string(forKey: SiriShortcutKeys.supabaseUrl) ?? "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    let supabaseAnonKey = (defaults.string(forKey: SiriShortcutKeys.supabaseAnonKey) ?? "")
      .trimmingCharacters(in: .whitespacesAndNewlines)

    let accessToken = (SharedKeychainStore.shared.read(account: SiriShortcutKeys.accessTokenAccount) ?? "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    let refreshToken = (SharedKeychainStore.shared.read(account: SiriShortcutKeys.refreshTokenAccount) ?? "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    let userId = (SharedKeychainStore.shared.read(account: SiriShortcutKeys.userIdAccount) ?? "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    let expiresAtValue = (SharedKeychainStore.shared.read(account: SiriShortcutKeys.expiresAtAccount) ?? "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    let expiresAt = Int(expiresAtValue) ?? 0

    guard !supabaseUrl.isEmpty,
          !supabaseAnonKey.isEmpty,
          !accessToken.isEmpty,
          !refreshToken.isEmpty,
          !userId.isEmpty else {
      return nil
    }

    return SiriShortcutAuthContext(
      supabaseUrl: supabaseUrl,
      supabaseAnonKey: supabaseAnonKey,
      accessToken: accessToken,
      refreshToken: refreshToken,
      userId: userId,
      expiresAt: expiresAt
    )
  }

  func persist() {
    guard let defaults = UserDefaults(suiteName: SiriShortcutKeys.appGroupId) else {
      return
    }
    defaults.set(supabaseUrl, forKey: SiriShortcutKeys.supabaseUrl)
    defaults.set(supabaseAnonKey, forKey: SiriShortcutKeys.supabaseAnonKey)

    SharedKeychainStore.shared.write(value: accessToken, account: SiriShortcutKeys.accessTokenAccount)
    SharedKeychainStore.shared.write(value: refreshToken, account: SiriShortcutKeys.refreshTokenAccount)
    SharedKeychainStore.shared.write(value: userId, account: SiriShortcutKeys.userIdAccount)
    SharedKeychainStore.shared.write(value: String(expiresAt), account: SiriShortcutKeys.expiresAtAccount)
  }
}

private final class SharedKeychainStore {
  static let shared = SharedKeychainStore()

  private func baseQuery(account: String) -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: SiriShortcutKeys.keychainService,
      kSecAttrAccount as String: account,
    ]
  }

  func read(account: String) -> String? {
    var query = baseQuery(account: account)
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne

    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    guard status == errSecSuccess,
          let data = item as? Data,
          let value = String(data: data, encoding: .utf8) else {
      return nil
    }
    return value
  }

  func write(value: String?, account: String) {
    let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines)
    if normalized == nil || normalized?.isEmpty == true {
      delete(account: account)
      return
    }

    let query = baseQuery(account: account)
    let data = Data((normalized ?? "").utf8)

    let updateStatus = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
    if updateStatus == errSecSuccess {
      return
    }

    var addQuery = query
    addQuery[kSecValueData as String] = data
    addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    SecItemAdd(addQuery as CFDictionary, nil)
  }

  func delete(account: String) {
    let query = baseQuery(account: account)
    SecItemDelete(query as CFDictionary)
  }

  func clearAll() {
    delete(account: SiriShortcutKeys.accessTokenAccount)
    delete(account: SiriShortcutKeys.refreshTokenAccount)
    delete(account: SiriShortcutKeys.userIdAccount)
    delete(account: SiriShortcutKeys.expiresAtAccount)
  }
}

private enum SiriShortcutIntentError: LocalizedError {
  case notConfigured
  case missingSession
  case invalidInput
  case duplicateRequest
  case noExpenseDetected
  case networkFailure
  case saveFailed

  var errorDescription: String? {
    switch self {
    case .notConfigured:
      return "Please open Moneko once to finish Siri setup."
    case .missingSession:
      return "Your session expired. Please open Moneko and sign in again."
    case .invalidInput:
      return "I could not understand that expense. Try saying amount and description."
    case .duplicateRequest:
      return "That sounds like a duplicate request. I skipped it to prevent double logging."
    case .noExpenseDetected:
      return "I could not detect an expense from that."
    case .networkFailure:
      return "I could not reach Moneko. Please try again."
    case .saveFailed:
      return "I analyzed the expense, but failed to save it. Please try again."
    }
  }
}

@available(iOS 16.0, *)
struct LogExpenseWithSiriIntent: AppIntent {
  static var title: LocalizedStringResource = "Log Expense"
  static var description = IntentDescription("Log an expense in Moneko using your voice.")

  @available(*, deprecated, message: "Use supportedModes when available.")
  static var openAppWhenRun: Bool { false }

  @Parameter(title: "Expense")
  var expenseText: String

  @Parameter(title: "Currency")
  var currencyCode: String?

  @Parameter(title: "Scope")
  var scopeName: String?

  func perform() async throws -> some IntentResult & ProvidesDialog {
    let normalizedText = expenseText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalizedText.isEmpty else {
      throw SiriShortcutIntentError.invalidInput
    }

    guard var context = SiriShortcutAuthContext.load() else {
      throw SiriShortcutIntentError.notConfigured
    }

    let idempotencyKey = makeIdempotencyKey(userId: context.userId, text: normalizedText)
    if !reserveIdempotencySlot(idempotencyKey: idempotencyKey) {
      throw SiriShortcutIntentError.duplicateRequest
    }

    var shouldKeepIdempotencySlot = false
    defer {
      if !shouldKeepIdempotencySlot {
        clearIdempotencySlot(idempotencyKey: idempotencyKey)
      }
    }

    if context.isAccessTokenExpired {
      context = try await refreshSession(context: context)
      context.persist()
    }

    let normalizedCurrency = normalizeCurrencyCode(currencyCode)
    let scopeResolution = resolveScope(scopeName)

    let analyzedItems = try await analyzeExpense(
      text: normalizedText,
      currencyCode: normalizedCurrency,
      scope: scopeResolution,
      context: context
    )
    guard !analyzedItems.isEmpty else {
      throw SiriShortcutIntentError.noExpenseDetected
    }

    let savedCount = try await persistTransactions(
      items: analyzedItems,
      scope: scopeResolution,
      context: context,
      idempotencyKey: idempotencyKey
    )
    guard savedCount > 0 else {
      throw SiriShortcutIntentError.saveFailed
    }

    let message = savedCount == 1
      ? "Logged 1 transaction in Moneko."
      : "Logged \(savedCount) transactions in Moneko."
    shouldKeepIdempotencySlot = true
    return .result(dialog: IntentDialog(stringLiteral: message))
  }

  private func refreshSession(context: SiriShortcutAuthContext) async throws -> SiriShortcutAuthContext {
    guard let url = URL(string: "\(context.supabaseUrl)/auth/v1/token?grant_type=refresh_token") else {
      throw SiriShortcutIntentError.notConfigured
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.timeoutInterval = 20
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(context.supabaseAnonKey, forHTTPHeaderField: "apikey")
    request.httpBody = try JSONSerialization.data(withJSONObject: ["refresh_token": context.refreshToken])

    let data: Data
    let response: URLResponse
    do {
      (data, response) = try await URLSession.shared.data(for: request)
    } catch {
      throw SiriShortcutIntentError.networkFailure
    }
    guard let httpResponse = response as? HTTPURLResponse else {
      throw SiriShortcutIntentError.networkFailure
    }
    guard (200...299).contains(httpResponse.statusCode) else {
      throw SiriShortcutIntentError.missingSession
    }

    guard
      let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      let accessToken = (json["access_token"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
      !accessToken.isEmpty
    else {
      throw SiriShortcutIntentError.missingSession
    }

    let refreshToken = ((json["refresh_token"] as? String) ?? context.refreshToken)
      .trimmingCharacters(in: .whitespacesAndNewlines)
    let user = json["user"] as? [String: Any]
    let userId = ((user?["id"] as? String) ?? context.userId)
      .trimmingCharacters(in: .whitespacesAndNewlines)
    let expiresAt = (json["expires_at"] as? Int) ?? context.expiresAt

    guard !refreshToken.isEmpty, !userId.isEmpty else {
      throw SiriShortcutIntentError.missingSession
    }

    return SiriShortcutAuthContext(
      supabaseUrl: context.supabaseUrl,
      supabaseAnonKey: context.supabaseAnonKey,
      accessToken: accessToken,
      refreshToken: refreshToken,
      userId: userId,
      expiresAt: expiresAt
    )
  }

  private func analyzeExpense(
    text: String,
    currencyCode: String?,
    scope: SiriShortcutScopeResolution,
    context: SiriShortcutAuthContext
  ) async throws -> [[String: Any]] {
    guard let url = URL(string: "\(context.supabaseUrl)/functions/v1/analyze-expense") else {
      throw SiriShortcutIntentError.notConfigured
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.timeoutInterval = 25
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(context.accessToken)", forHTTPHeaderField: "Authorization")
    request.setValue(context.supabaseAnonKey, forHTTPHeaderField: "apikey")

    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    dateFormatter.timeZone = .current
    dateFormatter.dateFormat = "yyyy-MM-dd"

    var body: [String: Any] = [
      "userId": context.userId,
      "date": dateFormatter.string(from: Date()),
      "language": Locale.current.identifier,
      "typeHint": "mixed",
      "text": text
    ]

    if let currencyCode, !currencyCode.isEmpty {
      body["currency"] = currencyCode
    }

    if let householdId = scope.householdId {
      body["householdId"] = householdId
      body["isPortfolio"] = scope.isPortfolio
    }

    request.httpBody = try JSONSerialization.data(withJSONObject: body)

    let data: Data
    let response: URLResponse
    do {
      (data, response) = try await URLSession.shared.data(for: request)
    } catch {
      throw SiriShortcutIntentError.networkFailure
    }
    guard let httpResponse = response as? HTTPURLResponse else {
      throw SiriShortcutIntentError.networkFailure
    }
    guard (200...299).contains(httpResponse.statusCode) else {
      throw SiriShortcutIntentError.networkFailure
    }

    guard
      let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      (json["success"] as? Bool) == true,
      let dataObject = json["data"] as? [String: Any],
      let items = dataObject["items"] as? [[String: Any]]
    else {
      throw SiriShortcutIntentError.noExpenseDetected
    }

    return items
  }

  private func persistTransactions(
    items: [[String: Any]],
    scope: SiriShortcutScopeResolution,
    context: SiriShortcutAuthContext,
    idempotencyKey: String
  ) async throws -> Int {
    let transactions = buildBatchTransactions(from: items)
    guard !transactions.isEmpty else {
      throw SiriShortcutIntentError.noExpenseDetected
    }

    guard let url = URL(string: "\(context.supabaseUrl)/functions/v1/save-transactions-batch") else {
      throw SiriShortcutIntentError.notConfigured
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.timeoutInterval = 25
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(context.accessToken)", forHTTPHeaderField: "Authorization")
    request.setValue(context.supabaseAnonKey, forHTTPHeaderField: "apikey")
    request.setValue(idempotencyKey, forHTTPHeaderField: "x-idempotency-key")

    var body: [String: Any] = [
      "userId": context.userId,
      "transactions": transactions
    ]
    if let householdId = scope.householdId {
      body["householdId"] = householdId
      body["isPortfolio"] = scope.isPortfolio
    }
    request.httpBody = try JSONSerialization.data(withJSONObject: body)

    let data: Data
    let response: URLResponse
    do {
      (data, response) = try await URLSession.shared.data(for: request)
    } catch {
      throw SiriShortcutIntentError.networkFailure
    }
    guard let httpResponse = response as? HTTPURLResponse else {
      throw SiriShortcutIntentError.networkFailure
    }
    guard (200...299).contains(httpResponse.statusCode) else {
      throw SiriShortcutIntentError.saveFailed
    }

    guard
      let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      let summary = json["summary"] as? [String: Any],
      let succeeded = summary["succeeded"] as? Int
    else {
      throw SiriShortcutIntentError.saveFailed
    }

    return succeeded
  }

  private func buildBatchTransactions(from items: [[String: Any]]) -> [[String: Any]] {
    let isoTimestamp = ISO8601DateFormatter().string(from: Date())
    var transactions: [[String: Any]] = []

    for item in items {
      guard
        let amountRaw = item["amount"] as? NSNumber,
        amountRaw.doubleValue > 0,
        let categoryRaw = item["category"] as? String,
        let currencyRaw = item["currency"] as? String,
        let dateRaw = item["date"] as? String
      else {
        continue
      }

      let typeRaw = ((item["type"] as? String) ?? "expense").lowercased()
      let normalizedType = typeRaw == "income" ? "income" : "expense"

      let category = categoryRaw.trimmingCharacters(in: .whitespacesAndNewlines)
      let currency = currencyRaw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
      let date = dateRaw.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !category.isEmpty, !currency.isEmpty, !date.isEmpty else {
        continue
      }

      var transaction: [String: Any] = [
        "type": normalizedType,
        "amount": amountRaw.doubleValue,
        "category": category,
        "currency": currency,
        "date": date,
        "clientCreatedAt": isoTimestamp
      ]

      if let description = (item["description"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
         !description.isEmpty {
        transaction["description"] = description
      }

      if let breakdown = item["breakdown"] as? [Any], !breakdown.isEmpty {
        transaction["breakdown"] = breakdown
      }

      transactions.append(transaction)
    }

    return transactions
  }

  private func normalizeCurrencyCode(_ rawValue: String?) -> String? {
    guard let rawValue else { return nil }
    let normalized = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    guard normalized.count == 3 else { return nil }
    return normalized
  }

  private func resolveScope(_ rawValue: String?) -> SiriShortcutScopeResolution {
    let fallback = SiriShortcutScopeResolution(householdId: nil, isPortfolio: false)
    guard let rawValue else { return fallback }
    let normalized = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if normalized.isEmpty || normalized == "personal" {
      return fallback
    }

    guard let defaults = UserDefaults(suiteName: SiriShortcutKeys.appGroupId),
          let json = defaults.string(forKey: "config_households"),
          let data = json.data(using: .utf8),
          let list = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
      return fallback
    }

    for item in list {
      let id = (item["id"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
      let name = (item["name"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
      if id.isEmpty || id == "personal" {
        continue
      }
      if normalized == id.lowercased() || normalized == name {
        return SiriShortcutScopeResolution(householdId: id, isPortfolio: false)
      }
    }

    return fallback
  }

  private func reserveIdempotencySlot(idempotencyKey: String) -> Bool {
    guard let defaults = UserDefaults(suiteName: SiriShortcutKeys.appGroupId) else {
      return true
    }

    let now = Int(Date().timeIntervalSince1970)
    let lastHash = defaults.string(forKey: SiriShortcutKeys.idempotencyHash)
    let lastTimestamp = defaults.integer(forKey: SiriShortcutKeys.idempotencyTimestamp)

    if lastHash == idempotencyKey && now - lastTimestamp <= 15 {
      return false
    }

    defaults.set(idempotencyKey, forKey: SiriShortcutKeys.idempotencyHash)
    defaults.set(now, forKey: SiriShortcutKeys.idempotencyTimestamp)
    return true
  }

  private func clearIdempotencySlot(idempotencyKey: String) {
    guard let defaults = UserDefaults(suiteName: SiriShortcutKeys.appGroupId) else {
      return
    }
    let lastHash = defaults.string(forKey: SiriShortcutKeys.idempotencyHash)
    if lastHash == idempotencyKey {
      defaults.removeObject(forKey: SiriShortcutKeys.idempotencyHash)
      defaults.removeObject(forKey: SiriShortcutKeys.idempotencyTimestamp)
    }
  }

  private func makeIdempotencyKey(userId: String, text: String) -> String {
    let normalizedText = text
      .lowercased()
      .components(separatedBy: .whitespacesAndNewlines)
      .filter { !$0.isEmpty }
      .joined(separator: " ")
    let minuteBucket = Int(Date().timeIntervalSince1970 / 60)
    let raw = "\(userId)|\(normalizedText)|\(minuteBucket)"
    let digest = SHA256.hash(data: Data(raw.utf8))
    return digest.map { String(format: "%02x", $0) }.joined()
  }
}

@available(iOS 16.0, *)
struct MonekoAppShortcutsProvider: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: LogExpenseWithSiriIntent(),
      phrases: [
        "Log expense with \(.applicationName)",
        "Add expense in \(.applicationName)",
        "Track spending with \(.applicationName)"
      ],
      shortTitle: "Log Expense",
      systemImageName: "mic.fill"
    )
  }

  static var shortcutTileColor: ShortcutTileColor {
    .teal
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    setupSiriShortcutAuthChannel()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func setupSiriShortcutAuthChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      DispatchQueue.main.async { [weak self] in
        self?.setupSiriShortcutAuthChannel()
      }
      return
    }

    let channel = FlutterMethodChannel(name: SiriShortcutChannel.name, binaryMessenger: controller.binaryMessenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case SiriShortcutChannel.syncAuthContext:
        self.handleSyncAuthContext(call: call, result: result)
      case SiriShortcutChannel.getStatus:
        self.handleGetStatus(result: result)
      case SiriShortcutChannel.clearAuthContext:
        self.handleClearAuthContext(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func handleSyncAuthContext(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let defaults = UserDefaults(suiteName: SiriShortcutKeys.appGroupId) else {
      result(FlutterError(code: "invalid_args", message: "Invalid sync args", details: nil))
      return
    }

    let supabaseUrl = (args["supabaseUrl"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    let supabaseAnonKey = (args["supabaseAnonKey"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    if !supabaseUrl.isEmpty {
      defaults.set(supabaseUrl, forKey: SiriShortcutKeys.supabaseUrl)
    }
    if !supabaseAnonKey.isEmpty {
      defaults.set(supabaseAnonKey, forKey: SiriShortcutKeys.supabaseAnonKey)
    }

    SharedKeychainStore.shared.write(
      value: args["accessToken"] as? String,
      account: SiriShortcutKeys.accessTokenAccount
    )
    SharedKeychainStore.shared.write(
      value: args["refreshToken"] as? String,
      account: SiriShortcutKeys.refreshTokenAccount
    )
    SharedKeychainStore.shared.write(
      value: args["userId"] as? String,
      account: SiriShortcutKeys.userIdAccount
    )

    if let expiresAt = args["expiresAt"] as? Int {
      SharedKeychainStore.shared.write(
        value: String(expiresAt),
        account: SiriShortcutKeys.expiresAtAccount
      )
    } else {
      SharedKeychainStore.shared.delete(account: SiriShortcutKeys.expiresAtAccount)
    }

    result(nil)
  }

  private func handleGetStatus(result: @escaping FlutterResult) {
    let defaults = UserDefaults(suiteName: SiriShortcutKeys.appGroupId)
    let hasSupabaseUrl = ((defaults?.string(forKey: SiriShortcutKeys.supabaseUrl) ?? "").isEmpty == false)
    let hasSupabaseAnon = ((defaults?.string(forKey: SiriShortcutKeys.supabaseAnonKey) ?? "").isEmpty == false)
    let hasAccessToken = ((SharedKeychainStore.shared.read(account: SiriShortcutKeys.accessTokenAccount) ?? "").isEmpty == false)
    let hasRefreshToken = ((SharedKeychainStore.shared.read(account: SiriShortcutKeys.refreshTokenAccount) ?? "").isEmpty == false)
    let hasUserId = ((SharedKeychainStore.shared.read(account: SiriShortcutKeys.userIdAccount) ?? "").isEmpty == false)

    result([
      "hasSupabaseConfig": hasSupabaseUrl && hasSupabaseAnon,
      "hasCredentials": hasAccessToken && hasRefreshToken && hasUserId,
      "isReady": hasSupabaseUrl && hasSupabaseAnon && hasAccessToken && hasRefreshToken && hasUserId,
    ])
  }

  private func handleClearAuthContext(result: @escaping FlutterResult) {
    let defaults = UserDefaults(suiteName: SiriShortcutKeys.appGroupId)
    defaults?.removeObject(forKey: SiriShortcutKeys.supabaseUrl)
    defaults?.removeObject(forKey: SiriShortcutKeys.supabaseAnonKey)
    SharedKeychainStore.shared.clearAll()
    result(nil)
  }
}
