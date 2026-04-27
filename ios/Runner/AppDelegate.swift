import UIKit
import Flutter
import AppIntents
import Foundation
import NaturalLanguage
import Security
import CryptoKit

private enum SiriShortcutChannel {
  static let name = "moneko/siri_shortcut_auth"
  static let syncAuthContext = "syncAuthContext"
  static let getStatus = "getStatus"
  static let clearAuthContext = "clearAuthContext"
  static let getWalletCaptureDebugReport = "getWalletCaptureDebugReport"
  static let clearWalletCaptureDebugReport = "clearWalletCaptureDebugReport"
  static let appendWalletCaptureDebugEntry = "appendWalletCaptureDebugEntry"
  static let syncPendingWalletCaptures = "syncPendingWalletCaptures"
}

private let walletPendingCaptureQueue = DispatchQueue(label: "com.moneko.wallet.pending-captures")

@available(iOS 16.0, watchOS 9.0, *)
private struct SiriAssistantResultPayload {
  let speech: String
  let shouldOpenApp: Bool
}

@available(iOS 16.0, watchOS 9.0, *)
private func refreshSiriShortcutSession(
  context: SiriShortcutAuthContext
) async throws -> SiriShortcutAuthContext {
  SiriShortcutDiagnostics.record(
    source: "shortcut",
    action: "refresh-session-start",
    message: "Refreshing Siri shortcut session.",
    details: [
      "userId": context.userId,
      "expiresAt": context.expiresAt,
    ]
  )
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
    SiriShortcutDiagnostics.record(
      source: "shortcut",
      action: "refresh-session-network-error",
      message: "Session refresh request failed.",
      details: [
        "error": error.localizedDescription,
      ]
    )
    throw SiriShortcutIntentError.networkFailure
  }
  guard let httpResponse = response as? HTTPURLResponse else {
    SiriShortcutDiagnostics.record(
      source: "shortcut",
      action: "refresh-session-invalid-response",
      message: "Session refresh response was not HTTP."
    )
    throw SiriShortcutIntentError.networkFailure
  }
  guard (200...299).contains(httpResponse.statusCode) else {
    SiriShortcutDiagnostics.record(
      source: "shortcut",
      action: "refresh-session-failed",
      message: "Session refresh returned a non-success status.",
      details: [
        "statusCode": httpResponse.statusCode,
        "body": truncateDiagnosticsBody(String(data: data, encoding: .utf8) ?? "<non-utf8>"),
      ]
    )
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

  SiriShortcutDiagnostics.record(
    source: "shortcut",
    action: "refresh-session-success",
    message: "Session refresh succeeded.",
    details: [
      "userId": userId,
      "expiresAt": expiresAt,
    ]
  )

  return SiriShortcutAuthContext(
    supabaseUrl: context.supabaseUrl,
    supabaseAnonKey: context.supabaseAnonKey,
    accessToken: accessToken,
    refreshToken: refreshToken,
    userId: userId,
    expiresAt: expiresAt
  )
}

@available(iOS 16.0, watchOS 9.0, *)
private func normalizeSiriCurrencyCode(_ rawValue: String?) -> String? {
  guard let rawValue else { return nil }
  let normalized = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
  guard normalized.count == 3 else { return nil }
  return normalized
}

@available(iOS 16.0, watchOS 9.0, *)
private func normalizeSiriPeriodLabel(_ rawValue: String?) -> String {
  let normalized = (rawValue ?? "")
    .trimmingCharacters(in: .whitespacesAndNewlines)
    .lowercased()

  switch normalized {
  case "today":
    return "today"
  case "this week", "weekly", "week":
    return "this week"
  case "last month":
    return "last month"
  default:
    return "this month"
  }
}

@available(iOS 16.0, watchOS 9.0, *)
private func siriPeriodMonth(from rawValue: String?) -> String {
  let now = Date()
  let calendar = Calendar(identifier: .gregorian)
  let normalized = normalizeSiriPeriodLabel(rawValue)
  let targetDate: Date
  if normalized == "last month",
     let previousMonth = calendar.date(byAdding: .month, value: -1, to: now) {
    targetDate = previousMonth
  } else {
    targetDate = now
  }

  let components = calendar.dateComponents([.year, .month], from: targetDate)
  let year = components.year ?? 1970
  let month = components.month ?? 1
  return String(format: "%04d-%02d", year, month)
}

@available(iOS 16.0, watchOS 9.0, *)
private func siriDateRange(for rawValue: String?) -> (startDate: String, endDate: String) {
  let normalized = normalizeSiriPeriodLabel(rawValue)
  let calendar = Calendar.current
  let now = Date()
  let formatter = DateFormatter()
  formatter.locale = Locale(identifier: "en_US_POSIX")
  formatter.timeZone = .current
  formatter.dateFormat = "yyyy-MM-dd"

  let endDate = calendar.startOfDay(for: now)
  let startDate: Date

  switch normalized {
  case "today":
    startDate = endDate
  case "this week":
    let weekday = calendar.component(.weekday, from: endDate)
    let offset = weekday == 1 ? 6 : weekday - 2
    startDate = calendar.date(byAdding: .day, value: -offset, to: endDate) ?? endDate
  case "last month":
    let components = calendar.dateComponents([.year, .month], from: endDate)
    let thisMonthStart = calendar.date(from: DateComponents(year: components.year, month: components.month, day: 1)) ?? endDate
    let previousMonthStart = calendar.date(byAdding: .month, value: -1, to: thisMonthStart) ?? thisMonthStart
    let previousMonthEnd = calendar.date(byAdding: .day, value: -1, to: thisMonthStart) ?? endDate
    return (
      formatter.string(from: previousMonthStart),
      formatter.string(from: previousMonthEnd)
    )
  default:
    let components = calendar.dateComponents([.year, .month], from: endDate)
    startDate = calendar.date(from: DateComponents(year: components.year, month: components.month, day: 1)) ?? endDate
  }

  return (
    formatter.string(from: startDate),
    formatter.string(from: endDate)
  )
}

@available(iOS 16.0, watchOS 9.0, *)
private func resolveSiriScope(_ rawValue: String?) -> SiriShortcutScopeResolution {
  let fallback = SiriShortcutScopeResolution(householdId: nil, isPortfolio: false)
  guard let rawValue else { return fallback }
  let normalized = normalizeScopeLookupValue(rawValue)
  let strippedNormalized = normalizeScopeLookupValue(rawValue, stripTrailingKeywords: true)
  if normalized.isEmpty || normalized == "personal" {
    return fallback
  }

  var strippedMatches: [SiriShortcutScopeResolution] = []

  for space in loadStoredSpaces() {
    if space.isPersonal {
      continue
    }
    let exactResolution = SiriShortcutScopeResolution(
      householdId: space.id,
      isPortfolio: space.isPortfolio
    )
    let normalizedId = normalizeScopeLookupValue(space.id)
    let normalizedName = normalizeScopeLookupValue(space.name)
    if normalized == normalizedId || normalized == normalizedName {
      return exactResolution
    }
    if strippedNormalized != normalized &&
      (strippedNormalized == normalizedId || strippedNormalized == normalizedName) {
      strippedMatches.append(exactResolution)
    }
  }

  if strippedMatches.count == 1 {
    return strippedMatches[0]
  }

  return fallback
}

@available(iOS 16.0, watchOS 9.0, *)
private func extractSiriScopeFromExpenseText(
  _ rawText: String
) -> SiriShortcutResolvedIntentInput? {
  let spaces = loadStoredSpaces()
    .filter { !$0.isPersonal }
    .sorted { $0.name.count > $1.name.count }
  guard !spaces.isEmpty else {
    return nil
  }

  for space in spaces {
    let nameVariants = [
      space.name,
      space.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    ]
    let escapedNamePattern = Set(nameVariants)
      .map(NSRegularExpression.escapedPattern(for:))
      .joined(separator: "|")
    let pattern = "\\s+(?:in|into|under)\\s+(?:(?:the|my)\\s+)?(?:\(escapedNamePattern))(?:\\s+(?:space|account))?[\\p{P}\\s]*$"
    guard let regex = try? NSRegularExpression(
      pattern: pattern,
      options: [.caseInsensitive]
    ) else {
      continue
    }

    let fullRange = NSRange(rawText.startIndex..<rawText.endIndex, in: rawText)
    guard let match = regex.firstMatch(in: rawText, options: [], range: fullRange),
          let matchRange = Range(match.range, in: rawText) else {
      continue
    }

    let cleanedText = rawText[..<matchRange.lowerBound]
      .trimmingCharacters(in: .whitespacesAndNewlines)
    guard !cleanedText.isEmpty else {
      continue
    }

    return SiriShortcutResolvedIntentInput(
      expenseText: cleanedText,
      scope: SiriShortcutScopeResolution(
        householdId: space.id,
        isPortfolio: space.isPortfolio
      )
    )
  }

  return nil
}

@available(iOS 16.0, watchOS 9.0, *)
private func resolveSiriTransactionInput(
  expenseText: String,
  scopeName: String?
) -> SiriShortcutResolvedIntentInput {
  let explicitScope = resolveSiriScope(scopeName)
  if explicitScope.householdId != nil {
    return SiriShortcutResolvedIntentInput(expenseText: expenseText, scope: explicitScope)
  }

  guard let extractedInput = extractSiriScopeFromExpenseText(expenseText) else {
    return SiriShortcutResolvedIntentInput(expenseText: expenseText, scope: explicitScope)
  }

  return extractedInput
}

@available(iOS 16.0, watchOS 9.0, *)
private func makeSiriTransactionIdempotencyKey(
  userId: String,
  text: String,
  scope: SiriShortcutScopeResolution,
  typeHint: String
) -> String {
  let normalizedText = text
    .lowercased()
    .components(separatedBy: .whitespacesAndNewlines)
    .filter { !$0.isEmpty }
    .joined(separator: " ")
  let scopeKey = scope.householdId ?? "personal"
  let minuteBucket = Int(Date().timeIntervalSince1970 / 60)
  let raw = "\(userId)|\(scopeKey)|\(typeHint)|\(normalizedText)|\(minuteBucket)"
  let digest = SHA256.hash(data: Data(raw.utf8))
  return digest.map { String(format: "%02x", $0) }.joined()
}

@available(iOS 16.0, watchOS 9.0, *)
private func reserveSiriTransactionIdempotencySlot(idempotencyKey: String) -> Bool {
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

@available(iOS 16.0, watchOS 9.0, *)
private func clearSiriTransactionIdempotencySlot(idempotencyKey: String) {
  guard let defaults = UserDefaults(suiteName: SiriShortcutKeys.appGroupId) else {
    return
  }
  let lastHash = defaults.string(forKey: SiriShortcutKeys.idempotencyHash)
  if lastHash == idempotencyKey {
    defaults.removeObject(forKey: SiriShortcutKeys.idempotencyHash)
    defaults.removeObject(forKey: SiriShortcutKeys.idempotencyTimestamp)
  }
}

@available(iOS 16.0, watchOS 9.0, *)
private func analyzeSiriTransactions(
  text: String,
  currencyCode: String?,
  scope: SiriShortcutScopeResolution,
  typeHint: String,
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
    "language": detectSiriInputLanguage(for: text),
    "typeHint": typeHint,
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

@available(iOS 16.0, watchOS 9.0, *)
private func parseSucceededValueForSiri(_ value: Any?) -> Int? {
  if let intValue = value as? Int {
    return intValue
  }
  if let numberValue = value as? NSNumber {
    return numberValue.intValue
  }
  if let stringValue = value as? String,
     let intValue = Int(stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) {
    return intValue
  }
  return nil
}

@available(iOS 16.0, watchOS 9.0, *)
private func extractSucceededCountForSiri(from json: [String: Any]) -> Int? {
  if let summary = json["summary"] as? [String: Any],
     let succeeded = parseSucceededValueForSiri(summary["succeeded"]) {
    return succeeded
  }

  if let dataObject = json["data"] as? [String: Any],
     let summary = dataObject["summary"] as? [String: Any],
     let succeeded = parseSucceededValueForSiri(summary["succeeded"]) {
    return succeeded
  }

  if let results = json["results"] as? [[String: Any]] {
    return results.reduce(into: 0) { count, item in
      if (item["success"] as? Bool) == true {
        count += 1
      }
    }
  }

  return nil
}

@available(iOS 16.0, watchOS 9.0, *)
private func buildSiriBatchTransactions(from items: [[String: Any]]) -> [[String: Any]] {
  let isoTimestamp = ISO8601DateFormatter().string(from: Date())
  var transactions: [[String: Any]] = []

  for item in items {
    let amountValue: Double
    if let numberValue = item["amount"] as? NSNumber {
      amountValue = numberValue.doubleValue
    } else if let stringValue = item["amount"] as? String,
              let parsedValue = Double(stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) {
      amountValue = parsedValue
    } else {
      amountValue = -1
    }

    guard
      amountValue > 0,
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
      "amount": amountValue,
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

    if let receiptImageUrl = (item["receiptImageUrl"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
       !receiptImageUrl.isEmpty {
      transaction["receiptImageUrl"] = receiptImageUrl
    }

    if let payerUserId = (item["payerUserId"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
       !payerUserId.isEmpty {
      transaction["payerUserId"] = payerUserId
    }

    if let customSplits = item["customSplits"] {
      transaction["customSplits"] = customSplits
    }

    if let source = (item["source"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
       !source.isEmpty {
      transaction["source"] = source
    }

    if let ownerType = (item["ownerType"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
       !ownerType.isEmpty {
      transaction["ownerType"] = ownerType
    }

    if let privacyScope = (item["privacyScope"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
       !privacyScope.isEmpty {
      transaction["privacyScope"] = privacyScope
    }

    if let isRecurring = item["isRecurring"] as? Bool {
      transaction["isRecurring"] = isRecurring
    }

    if let recurrenceRule = item["recurrence_rule"] {
      transaction["recurrence_rule"] = recurrenceRule
    }

    transactions.append(transaction)
  }

  return transactions
}

@available(iOS 16.0, watchOS 9.0, *)
private func persistSiriTransactionsIndividually(
  transactions: [[String: Any]],
  scope: SiriShortcutScopeResolution,
  context: SiriShortcutAuthContext,
  idempotencyKey: String
) async throws -> Int {
  var savedCount = 0

  for (index, transaction) in transactions.enumerated() {
    let normalizedType = ((transaction["type"] as? String) ?? "expense").lowercased()
    let endpoint = normalizedType == "income" ? "save-income" : "save-expense"

    guard let url = URL(string: "\(context.supabaseUrl)/functions/v1/\(endpoint)") else {
      continue
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.timeoutInterval = 25
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(context.accessToken)", forHTTPHeaderField: "Authorization")
    request.setValue(context.supabaseAnonKey, forHTTPHeaderField: "apikey")
    request.setValue("\(idempotencyKey)-\(index)", forHTTPHeaderField: "x-idempotency-key")

    var body: [String: Any] = [
      "userId": context.userId,
    ]
    for (key, value) in transaction {
      if key == "type" {
        continue
      }
      body[key] = value
    }
    if let householdId = scope.householdId {
      body["householdId"] = householdId
      body["isPortfolio"] = scope.isPortfolio
    }

    request.httpBody = try JSONSerialization.data(withJSONObject: body)

    do {
      let (data, response) = try await URLSession.shared.data(for: request)
      guard let httpResponse = response as? HTTPURLResponse else {
        continue
      }

      if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
        throw SiriShortcutIntentError.missingSession
      }

      guard (200...299).contains(httpResponse.statusCode) else {
        continue
      }

      guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        continue
      }

      if json["id"] != nil {
        savedCount += 1
        continue
      }

      if let dataObject = json["data"] as? [String: Any], dataObject["id"] != nil {
        savedCount += 1
      }
    } catch let intentError as SiriShortcutIntentError {
      throw intentError
    } catch {
      continue
    }
  }

  return savedCount
}

@available(iOS 16.0, watchOS 9.0, *)
private func persistSiriTransactions(
  items: [[String: Any]],
  scope: SiriShortcutScopeResolution,
  context: SiriShortcutAuthContext,
  idempotencyKey: String
) async throws -> Int {
  let transactions = buildSiriBatchTransactions(from: items)
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
  if (200...299).contains(httpResponse.statusCode) {
    do {
      if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
         let succeeded = extractSucceededCountForSiri(from: json),
         succeeded > 0 {
        return succeeded
      }
    } catch {
      throw SiriShortcutIntentError.saveFailed
    }

    throw SiriShortcutIntentError.saveFailed
  }

  if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
    throw SiriShortcutIntentError.missingSession
  }

  if httpResponse.statusCode == 409 {
    throw SiriShortcutIntentError.duplicateRequest
  }

  if httpResponse.statusCode == 429 {
    throw SiriShortcutIntentError.networkFailure
  }

  if httpResponse.statusCode == 404 {
    let fallbackCount = try await persistSiriTransactionsIndividually(
      transactions: transactions,
      scope: scope,
      context: context,
      idempotencyKey: idempotencyKey
    )
    if fallbackCount > 0 {
      return fallbackCount
    }
  }
  throw SiriShortcutIntentError.saveFailed
}

@available(iOS 16.0, watchOS 9.0, *)
private func performSiriTransactionLogging(
  text: String,
  currencyCode: String?,
  scopeName: String?,
  typeHint: String
) async throws -> String {
  let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
  guard !normalizedText.isEmpty else {
    throw SiriShortcutIntentError.invalidInput
  }

  guard var context = SiriShortcutAuthContext.load() else {
    throw SiriShortcutIntentError.notConfigured
  }

  let resolvedInput = resolveSiriTransactionInput(expenseText: normalizedText, scopeName: scopeName)
  guard !resolvedInput.expenseText.isEmpty else {
    throw SiriShortcutIntentError.invalidInput
  }

  let idempotencyKey = makeSiriTransactionIdempotencyKey(
    userId: context.userId,
    text: resolvedInput.expenseText,
    scope: resolvedInput.scope,
    typeHint: typeHint
  )
  if !reserveSiriTransactionIdempotencySlot(idempotencyKey: idempotencyKey) {
    return "That transaction was already logged in Moneko."
  }

  var shouldKeepIdempotencySlot = false
  defer {
    if !shouldKeepIdempotencySlot {
      clearSiriTransactionIdempotencySlot(idempotencyKey: idempotencyKey)
    }
  }

  if context.isAccessTokenExpired {
    context = try await refreshSiriShortcutSession(context: context)
    context.persist()
  }

  let normalizedCurrency = normalizeSiriCurrencyCode(currencyCode)
  let analyzedItems = try await analyzeSiriTransactions(
    text: resolvedInput.expenseText,
    currencyCode: normalizedCurrency,
    scope: resolvedInput.scope,
    typeHint: typeHint,
    context: context
  )
  guard !analyzedItems.isEmpty else {
    throw SiriShortcutIntentError.noExpenseDetected
  }

  let savedCount: Int
  do {
    savedCount = try await persistSiriTransactions(
      items: analyzedItems,
      scope: resolvedInput.scope,
      context: context,
      idempotencyKey: idempotencyKey
    )
  } catch SiriShortcutIntentError.duplicateRequest {
    shouldKeepIdempotencySlot = true
    return "That transaction was already logged in Moneko."
  }

  guard savedCount > 0 else {
    throw SiriShortcutIntentError.saveFailed
  }

  shouldKeepIdempotencySlot = true
  if typeHint == "income" {
    return savedCount == 1
      ? "Logged 1 income transaction in Moneko."
      : "Logged \(savedCount) income transactions in Moneko."
  }

  return savedCount == 1
    ? "Logged 1 transaction in Moneko."
    : "Logged \(savedCount) transactions in Moneko."
}

@available(iOS 16.0, watchOS 9.0, *)
private func performSiriAssistantAction(
  action: String,
  scopeName: String?,
  currencyCode: String?,
  amount: Double? = nil,
  periodName: String? = nil
) async throws -> SiriAssistantResultPayload {
  guard var context = SiriShortcutAuthContext.load() else {
    throw SiriShortcutIntentError.notConfigured
  }

  if context.isAccessTokenExpired {
    context = try await refreshSiriShortcutSession(context: context)
    context.persist()
  }

  guard let url = URL(string: "\(context.supabaseUrl)/functions/v1/siri-assistant") else {
    throw SiriShortcutIntentError.notConfigured
  }

  var request = URLRequest(url: url)
  request.httpMethod = "POST"
  request.timeoutInterval = 20
  request.setValue("application/json", forHTTPHeaderField: "Content-Type")
  request.setValue("Bearer \(context.accessToken)", forHTTPHeaderField: "Authorization")
  request.setValue(context.supabaseAnonKey, forHTTPHeaderField: "apikey")

  let scope = resolveSiriScope(scopeName)
  let normalizedPeriod = normalizeSiriPeriodLabel(periodName)

  var body: [String: Any] = [
    "action": action,
    "periodLabel": normalizedPeriod,
    "periodMonth": siriPeriodMonth(from: periodName)
  ]
  if action.hasPrefix("spend.") {
    let range = siriDateRange(for: periodName)
    body["startDate"] = range.startDate
    body["endDate"] = range.endDate
  }
  if let normalizedCurrency = normalizeSiriCurrencyCode(currencyCode) {
    body["currency"] = normalizedCurrency
  }
  if let amount {
    body["amount"] = amount
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

  if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
    throw SiriShortcutIntentError.missingSession
  }

  guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
    throw SiriShortcutIntentError.requestFailed
  }

  guard (200...299).contains(httpResponse.statusCode),
        (json["success"] as? Bool) != false else {
    throw SiriShortcutIntentError.requestFailed
  }

  let dataObject = (json["data"] as? [String: Any]) ?? json
  let speech = (dataObject["speech"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
  guard !speech.isEmpty else {
    throw SiriShortcutIntentError.requestFailed
  }

  return SiriAssistantResultPayload(
    speech: speech,
    shouldOpenApp: dataObject["shouldOpenApp"] as? Bool ?? false
  )
}

@available(iOS 16.0, watchOS 9.0, *)
struct LogIncomeWithSiriIntent: AppIntent {
  static var title: LocalizedStringResource = "Log Income"
  static var description = IntentDescription("Log income in Moneko using your voice.")

  @available(*, deprecated, message: "Use supportedModes when available.")
  static var openAppWhenRun: Bool { false }

  @Parameter(title: "Income")
  var incomeText: String

  @Parameter(title: "Currency")
  var currencyCode: String?

  @Parameter(title: "Scope")
  var scopeName: String?

  func perform() async throws -> some IntentResult & ProvidesDialog {
    let message = try await performSiriTransactionLogging(
      text: incomeText,
      currencyCode: currencyCode,
      scopeName: scopeName,
      typeHint: "income"
    )
    return .result(dialog: IntentDialog(stringLiteral: message))
  }
}

@available(iOS 16.0, watchOS 9.0, *)
struct SetBudgetWithSiriIntent: AppIntent {
  static var title: LocalizedStringResource = "Set Budget"
  static var description = IntentDescription("Set this month's budget in Moneko.")

  @available(*, deprecated, message: "Use supportedModes when available.")
  static var openAppWhenRun: Bool { false }

  @Parameter(title: "Amount")
  var amount: Double

  @Parameter(title: "Currency")
  var currencyCode: String?

  @Parameter(title: "Scope")
  var scopeName: String?

  func perform() async throws -> some IntentResult & ProvidesDialog {
    guard amount > 0 else {
      throw SiriShortcutIntentError.invalidInput
    }

    let result = try await performSiriAssistantAction(
      action: "budget.set_total",
      scopeName: scopeName,
      currencyCode: currencyCode,
      amount: amount
    )
    return .result(dialog: IntentDialog(stringLiteral: result.speech))
  }
}

@available(iOS 16.0, watchOS 9.0, *)
struct CheckBudgetWithSiriIntent: AppIntent {
  static var title: LocalizedStringResource = "Check Budget"
  static var description = IntentDescription("Check your current budget status in Moneko.")

  @available(*, deprecated, message: "Use supportedModes when available.")
  static var openAppWhenRun: Bool { false }

  @Parameter(title: "Currency")
  var currencyCode: String?

  @Parameter(title: "Scope")
  var scopeName: String?

  func perform() async throws -> some IntentResult & ProvidesDialog {
    let result = try await performSiriAssistantAction(
      action: "budget.status",
      scopeName: scopeName,
      currencyCode: currencyCode
    )
    return .result(dialog: IntentDialog(stringLiteral: result.speech))
  }
}

@available(iOS 16.0, watchOS 9.0, *)
struct CheckSpendingWithSiriIntent: AppIntent {
  static var title: LocalizedStringResource = "Check Spending"
  static var description = IntentDescription("Ask Moneko how much you spent in a period or space.")

  @available(*, deprecated, message: "Use supportedModes when available.")
  static var openAppWhenRun: Bool { false }

  @Parameter(title: "Period")
  var periodName: String?

  @Parameter(title: "Currency")
  var currencyCode: String?

  @Parameter(title: "Scope")
  var scopeName: String?

  func perform() async throws -> some IntentResult & ProvidesDialog {
    let result = try await performSiriAssistantAction(
      action: "spend.total",
      scopeName: scopeName,
      currencyCode: currencyCode,
      periodName: periodName
    )
    return .result(dialog: IntentDialog(stringLiteral: result.speech))
  }
}

@available(iOS 16.0, watchOS 9.0, *)
struct AnalyzeSpendingWithSiriIntent: AppIntent {
  static var title: LocalizedStringResource = "Analyze Spending"
  static var description = IntentDescription("Get a concise spending analysis from Moneko and open the app for details.")

  @available(*, deprecated, message: "Use supportedModes when available.")
  static var openAppWhenRun: Bool { true }

  @Parameter(title: "Period")
  var periodName: String?

  @Parameter(title: "Currency")
  var currencyCode: String?

  @Parameter(title: "Scope")
  var scopeName: String?

  func perform() async throws -> some IntentResult & ProvidesDialog {
    let result = try await performSiriAssistantAction(
      action: "spend.analysis",
      scopeName: scopeName,
      currencyCode: currencyCode,
      periodName: periodName
    )
    let dialog = result.shouldOpenApp
      ? "\(result.speech) Opening Moneko for more detail."
      : result.speech
    return .result(dialog: IntentDialog(stringLiteral: dialog))
  }
}

private func walletCaptureConfigOwnerMatches(
  defaults: UserDefaults,
  expectedUserId: String
) -> Bool {
  let ownerUserId = (defaults.string(forKey: SiriShortcutKeys.walletConfigUserId) ?? "")
    .trimmingCharacters(in: .whitespacesAndNewlines)
  guard !ownerUserId.isEmpty, ownerUserId == expectedUserId else {
    SiriShortcutDiagnostics.record(
      source: "native",
      action: "wallet-config-owner-mismatch",
      message: "Wallet capture config does not belong to the active user.",
      details: [
        "hasOwner": !ownerUserId.isEmpty,
        "expectedUserId": expectedUserId,
      ]
    )
    return false
  }
  return true
}

@available(iOS 16.0, watchOS 9.0, *)
private func loadWalletCaptureScope(expectedUserId: String) -> SiriShortcutScopeResolution? {
  guard let defaults = UserDefaults(suiteName: SiriShortcutKeys.appGroupId) else {
    SiriShortcutDiagnostics.record(
      source: "native",
      action: "wallet-scope-defaults-missing",
      message: "Unable to read wallet capture scope because app group defaults are unavailable."
    )
    return nil
  }

  guard walletCaptureConfigOwnerMatches(
    defaults: defaults,
    expectedUserId: expectedUserId
  ) else {
    return nil
  }

  guard defaults.bool(forKey: SiriShortcutKeys.walletCaptureEnabled) else {
    SiriShortcutDiagnostics.record(
      source: "native",
      action: "wallet-scope-disabled",
      message: "Wallet capture scope requested while wallet capture is disabled."
    )
    return nil
  }

  let scopeId = (defaults.string(forKey: SiriShortcutKeys.walletDefaultScopeId) ?? "")
    .trimmingCharacters(in: .whitespacesAndNewlines)

  if scopeId.isEmpty || scopeId == "personal" {
    return SiriShortcutScopeResolution(householdId: nil, isPortfolio: false)
  }

  let isPortfolio = defaults.bool(forKey: SiriShortcutKeys.walletDefaultIsPortfolio)
  return SiriShortcutScopeResolution(householdId: scopeId, isPortfolio: isPortfolio)
}

@available(iOS 16.0, watchOS 9.0, *)
private func loadWalletCaptureAccountId() -> String? {
  guard let defaults = UserDefaults(suiteName: SiriShortcutKeys.appGroupId) else {
    return nil
  }

  let accountId = (defaults.string(forKey: SiriShortcutKeys.walletDefaultAccountId) ?? "")
    .trimmingCharacters(in: .whitespacesAndNewlines)
  return accountId.isEmpty ? nil : accountId
}

@available(iOS 16.0, watchOS 9.0, *)
private func makeWalletIdempotencyKey(
  userId: String,
  merchantName: String?,
  amount: Double,
  currencyCode: String?,
  transactionDate: String?,
  scope: SiriShortcutScopeResolution
) -> String {
  let normalizedMerchant = (merchantName ?? "")
    .lowercased()
    .components(separatedBy: .whitespacesAndNewlines)
    .filter { !$0.isEmpty }
    .joined(separator: " ")
  let normalizedCurrency = (currencyCode ?? "")
    .trimmingCharacters(in: .whitespacesAndNewlines)
    .uppercased()
  let normalizedDate = (transactionDate ?? "")
    .trimmingCharacters(in: .whitespacesAndNewlines)
  let scopeKey = scope.householdId ?? "personal"
  let amountCents = Int(round(amount * 100))
  let minuteBucket = Int(Date().timeIntervalSince1970 / 60)
  let raw = "wallet|\(userId)|\(scopeKey)|\(normalizedMerchant)|\(amountCents)|\(normalizedCurrency)|\(normalizedDate)|\(minuteBucket)"
  let digest = SHA256.hash(data: Data(raw.utf8))
  return digest.map { String(format: "%02x", $0) }.joined()
}

@available(iOS 16.0, watchOS 9.0, *)
private func reserveWalletIdempotencySlot(idempotencyKey: String) -> Bool {
  guard let defaults = UserDefaults(suiteName: SiriShortcutKeys.appGroupId) else {
    return true
  }

  let now = Int(Date().timeIntervalSince1970)
  let lastHash = defaults.string(forKey: SiriShortcutKeys.walletIdempotencyHash)
  let lastTimestamp = defaults.integer(forKey: SiriShortcutKeys.walletIdempotencyTimestamp)

  if lastHash == idempotencyKey && now - lastTimestamp <= 15 {
    return false
  }

  defaults.set(idempotencyKey, forKey: SiriShortcutKeys.walletIdempotencyHash)
  defaults.set(now, forKey: SiriShortcutKeys.walletIdempotencyTimestamp)
  return true
}

@available(iOS 16.0, watchOS 9.0, *)
private func clearWalletIdempotencySlot(idempotencyKey: String) {
  guard let defaults = UserDefaults(suiteName: SiriShortcutKeys.appGroupId) else {
    return
  }
  let lastHash = defaults.string(forKey: SiriShortcutKeys.walletIdempotencyHash)
  if lastHash == idempotencyKey {
    defaults.removeObject(forKey: SiriShortcutKeys.walletIdempotencyHash)
    defaults.removeObject(forKey: SiriShortcutKeys.walletIdempotencyTimestamp)
  }
}

@available(iOS 16.0, watchOS 9.0, *)
private func resolveWalletCaptureIntentError(
  statusCode: Int,
  data: Data
) -> SiriShortcutIntentError {
  let responseBody = String(data: data, encoding: .utf8) ?? "<non-utf8>"

  guard
    let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
  else {
    if statusCode == 401 {
      return .missingSession
    }
    return .backendError(
      message: "Wallet capture failed (\(statusCode)). Please try again.",
      code: nil
    )
  }

  let backendCode = (json["code"] as? String)?
    .trimmingCharacters(in: .whitespacesAndNewlines)
    .uppercased()
  let backendMessage = (json["error"] as? String)?
    .trimmingCharacters(in: .whitespacesAndNewlines)

  switch backendCode {
  case "WALLET_CAPTURE_DISABLED":
    return .backendError(
      message: backendMessage ?? "Wallet capture is disabled in Moneko.",
      code: backendCode
    )
  case "AUTH_REQUIRED", "UNAUTHORIZED":
    return .missingSession
  case "DUPLICATE_REQUEST":
    return .duplicateRequest
  default:
    break
  }

  if statusCode == 401 {
    return .missingSession
  }

  if let backendMessage, !backendMessage.isEmpty {
    return .backendError(message: backendMessage, code: backendCode)
  }

  return .backendError(
    message: "Wallet capture failed (\(statusCode)): \(responseBody)",
    code: backendCode
  )
}

private func loadPendingWalletCaptureRecordsUnlocked() -> [[String: Any]] {
  guard
    let json = SharedKeychainStore.shared.read(
      account: SiriShortcutKeys.walletPendingCaptures,
      logFailure: false
    ),
    let data = json.data(using: .utf8),
    let records = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
  else {
    return []
  }
  return records
}

private func loadPendingWalletCaptureRecords() -> [[String: Any]] {
  walletPendingCaptureQueue.sync {
    loadPendingWalletCaptureRecordsUnlocked()
  }
}

private func savePendingWalletCaptureRecordsUnlocked(_ records: [[String: Any]]) -> Bool {
  guard !records.isEmpty else {
    SharedKeychainStore.shared.delete(account: SiriShortcutKeys.walletPendingCaptures)
    return SharedKeychainStore.shared.read(
      account: SiriShortcutKeys.walletPendingCaptures,
      logFailure: false
    ) == nil
  }

  do {
    let data = try JSONSerialization.data(withJSONObject: records)
    guard let json = String(data: data, encoding: .utf8) else {
      throw SiriShortcutIntentError.saveFailed
    }
    SharedKeychainStore.shared.write(
      value: json,
      account: SiriShortcutKeys.walletPendingCaptures
    )
    return SharedKeychainStore.shared.read(
      account: SiriShortcutKeys.walletPendingCaptures,
      logFailure: false
    ) == json
  } catch {
    SiriShortcutDiagnostics.record(
      source: "native",
      action: "wallet-pending-save-failed",
      message: "Unable to persist pending wallet captures.",
      details: [
        "error": error.localizedDescription,
      ]
    )
    return false
  }
}

@discardableResult
private func savePendingWalletCaptureRecords(_ records: [[String: Any]]) -> Bool {
  walletPendingCaptureQueue.sync {
    savePendingWalletCaptureRecordsUnlocked(records)
  }
}

private func mergePendingWalletCaptureSyncResults(
  completedIdempotencyKeys: Set<String>,
  updatedRecordsByIdempotencyKey: [String: [String: Any]]
) -> Int {
  walletPendingCaptureQueue.sync {
    let latestRecords = loadPendingWalletCaptureRecordsUnlocked()
    let mergedRecords = latestRecords.compactMap { record -> [String: Any]? in
      guard let idempotencyKey = record["idempotencyKey"] as? String else {
        return nil
      }
      if completedIdempotencyKeys.contains(idempotencyKey) {
        return nil
      }
      return updatedRecordsByIdempotencyKey[idempotencyKey] ?? record
    }
    _ = savePendingWalletCaptureRecordsUnlocked(mergedRecords)
    return mergedRecords.count
  }
}

private func updatedPendingWalletCaptureRecord(
  _ record: [String: Any],
  error: String
) -> [String: Any] {
  var updated = record
  let attemptCount = (record["attemptCount"] as? Int ?? 0) + 1
  updated["attemptCount"] = attemptCount
  updated["lastAttemptAt"] = makeDiagnosticsTimestamp()
  updated["lastError"] = error
  return updated
}

@available(iOS 16.0, watchOS 9.0, *)
private func enqueuePendingWalletCapture(
  body: [String: Any],
  idempotencyKey: String,
  userId: String,
  merchantName: String,
  amount: Double
) -> Bool {
  walletPendingCaptureQueue.sync {
    var records = loadPendingWalletCaptureRecordsUnlocked()
    if records.contains(where: { ($0["idempotencyKey"] as? String) == idempotencyKey }) {
      SiriShortcutDiagnostics.record(
        source: "shortcut",
        action: "wallet-offline-queue-duplicate",
        message: "Wallet capture was already queued for offline sync.",
        details: [
          "idempotencyKey": idempotencyKey,
        ]
      )
      return false
    }

    guard records.count < 100 else {
      SiriShortcutDiagnostics.record(
        source: "shortcut",
        action: "wallet-offline-queue-full",
        message: "Wallet capture could not be queued because the offline queue is full.",
        details: [
          "pendingCount": records.count,
        ]
      )
      return false
    }

    records.append([
      "id": UUID().uuidString,
      "idempotencyKey": idempotencyKey,
      "userId": userId,
      "merchantName": merchantName,
      "amount": amount,
      "queuedAt": makeDiagnosticsTimestamp(),
      "attemptCount": 0,
      "body": body,
    ])

    guard savePendingWalletCaptureRecordsUnlocked(records) else {
      SiriShortcutDiagnostics.record(
        source: "shortcut",
        action: "wallet-offline-queue-save-failed",
        message: "Wallet capture could not be saved locally for offline sync.",
        details: [
          "merchant": merchantName,
          "amount": amount,
        ]
      )
      return false
    }

    SiriShortcutDiagnostics.record(
      source: "shortcut",
      action: "wallet-offline-queued",
      message: "Wallet capture was saved locally for later sync.",
      details: [
        "merchant": merchantName,
        "amount": amount,
        "pendingCount": records.count,
      ]
    )
    return true
  }
}

@available(iOS 16.0, watchOS 9.0, *)
private func makeWalletCaptureRequestBody(
  userId: String,
  idempotencyKey: String,
  merchantName: String,
  amount: Double,
  scope: SiriShortcutScopeResolution,
  accountId: String?
) -> [String: Any] {
  let transaction: [String: Any] = [
    "amount": amount,
    "merchantName": merchantName,
  ]
  var body: [String: Any] = [
    "captureSource": "ios_wallet_shortcut",
    "idempotencyKey": idempotencyKey,
    "clientCreatedAt": ISO8601DateFormatter().string(from: Date()),
    "transaction": transaction,
  ]
  if let householdId = scope.householdId {
    body["householdId"] = householdId
    body["isPortfolio"] = scope.isPortfolio
  }
  if let accountId {
    body["accountId"] = accountId
  }
  return body
}

@available(iOS 16.0, watchOS 9.0, *)
private func submitWalletCaptureRequestBody(
  _ body: [String: Any],
  context: SiriShortcutAuthContext
) async throws -> Bool {
  guard let url = URL(string: "\(context.supabaseUrl)/functions/v1/save-wallet-transaction") else {
    throw SiriShortcutIntentError.notConfigured
  }

  var request = URLRequest(url: url)
  request.httpMethod = "POST"
  request.timeoutInterval = 25
  request.setValue("application/json", forHTTPHeaderField: "Content-Type")
  request.setValue("Bearer \(context.accessToken)", forHTTPHeaderField: "Authorization")
  request.setValue(context.supabaseAnonKey, forHTTPHeaderField: "apikey")
  request.httpBody = try JSONSerialization.data(withJSONObject: body)

  NSLog("[MonekoCap] Calling save-wallet-transaction, url=%@", url.absoluteString)
  NSLog("[MonekoCap] Request body=%@", String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "<nil>")
  SiriShortcutDiagnostics.record(
    source: "shortcut",
    action: "wallet-request-start",
    message: "Calling save-wallet-transaction edge function.",
    details: [
      "url": url.absoluteString,
      "body": truncateDiagnosticsBody(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "<nil>"),
    ]
  )

  let data: Data
  let response: URLResponse
  do {
    (data, response) = try await URLSession.shared.data(for: request)
  } catch {
    NSLog("[MonekoCap] Network error: %@", error.localizedDescription)
    SiriShortcutDiagnostics.record(
      source: "shortcut",
      action: "wallet-request-network-error",
      message: "Wallet capture network request failed.",
      details: [
        "error": error.localizedDescription,
      ]
    )
    throw SiriShortcutIntentError.networkFailure
  }
  guard let httpResponse = response as? HTTPURLResponse else {
    NSLog("[MonekoCap] Response is not HTTPURLResponse")
    SiriShortcutDiagnostics.record(
      source: "shortcut",
      action: "wallet-request-invalid-response",
      message: "Wallet capture response was not HTTP."
    )
    throw SiriShortcutIntentError.networkFailure
  }

  let responseBody = String(data: data, encoding: .utf8) ?? "<non-utf8>"
  NSLog("[MonekoCap] HTTP %d — body: %@", httpResponse.statusCode, responseBody)
  SiriShortcutDiagnostics.record(
    source: "shortcut",
    action: "wallet-request-finished",
    message: "Wallet capture edge function returned a response.",
    details: [
      "statusCode": httpResponse.statusCode,
      "body": truncateDiagnosticsBody(responseBody),
    ]
  )

  if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
    throw resolveWalletCaptureIntentError(
      statusCode: httpResponse.statusCode,
      data: data
    )
  }

  if httpResponse.statusCode == 409 {
    SiriShortcutDiagnostics.record(
      source: "shortcut",
      action: "wallet-duplicate-confirmed",
      message: "Wallet capture server reported a duplicate request."
    )
    return true
  }

  guard (200...299).contains(httpResponse.statusCode) else {
    NSLog("[MonekoCap] saveFailed — non-2xx status %d", httpResponse.statusCode)
    throw resolveWalletCaptureIntentError(
      statusCode: httpResponse.statusCode,
      data: data
    )
  }

  guard
    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
    (json["success"] as? Bool) == true
  else {
    NSLog("[MonekoCap] saveFailed — response JSON missing success:true, body: %@", responseBody)
    throw resolveWalletCaptureIntentError(
      statusCode: httpResponse.statusCode,
      data: data
    )
  }

  if (json["duplicate"] as? Bool) == true {
    SiriShortcutDiagnostics.record(
      source: "shortcut",
      action: "wallet-duplicate-json",
      message: "Wallet capture JSON payload marked this request as a duplicate."
    )
    return true
  }

  return false
}

@available(iOS 16.0, watchOS 9.0, *)
private func syncPendingWalletCaptures() async -> [String: Any] {
  let records = loadPendingWalletCaptureRecords()
  guard !records.isEmpty else {
    return [
      "attempted": 0,
      "synced": 0,
      "remaining": 0,
    ]
  }

  SiriShortcutDiagnostics.record(
    source: "native",
    action: "wallet-pending-sync-start",
    message: "Starting pending wallet capture sync.",
    details: [
      "pendingCount": records.count,
    ]
  )

  guard var context = SiriShortcutAuthContext.load(logFailure: false) else {
    SiriShortcutDiagnostics.record(
      source: "native",
      action: "wallet-pending-sync-missing-auth",
      message: "Pending wallet captures could not sync because auth context is missing.",
      details: [
        "pendingCount": records.count,
      ]
    )
    return [
      "attempted": 0,
      "synced": 0,
      "remaining": records.count,
    ]
  }

  if context.isAccessTokenExpired {
    do {
      context = try await refreshSiriShortcutSession(context: context)
      context.persist()
    } catch {
      SiriShortcutDiagnostics.record(
        source: "native",
        action: "wallet-pending-sync-refresh-failed",
        message: "Pending wallet captures could not sync because session refresh failed.",
        details: [
          "error": error.localizedDescription,
          "pendingCount": records.count,
        ]
      )
      return [
        "attempted": 0,
        "synced": 0,
        "remaining": records.count,
      ]
    }
  }

  var attempted = 0
  var synced = 0
  var completedIdempotencyKeys = Set<String>()
  var updatedRecordsByIdempotencyKey: [String: [String: Any]] = [:]

  for record in records {
    guard let idempotencyKey = record["idempotencyKey"] as? String,
          let body = record["body"] as? [String: Any] else {
      SiriShortcutDiagnostics.record(
        source: "native",
        action: "wallet-pending-sync-invalid-record",
        message: "Dropping malformed pending wallet capture record."
      )
      continue
    }

    guard (record["userId"] as? String) == context.userId else {
      continue
    }

    attempted += 1
    do {
      _ = try await submitWalletCaptureRequestBody(body, context: context)
      synced += 1
      completedIdempotencyKeys.insert(idempotencyKey)
    } catch SiriShortcutIntentError.networkFailure {
      let updated = updatedPendingWalletCaptureRecord(record, error: "networkFailure")
      updatedRecordsByIdempotencyKey[idempotencyKey] = updated
      break
    } catch SiriShortcutIntentError.missingSession {
      let updated = updatedPendingWalletCaptureRecord(record, error: "missingSession")
      updatedRecordsByIdempotencyKey[idempotencyKey] = updated
      break
    } catch {
      let updated = updatedPendingWalletCaptureRecord(record, error: error.localizedDescription)
      if (updated["attemptCount"] as? Int ?? 0) < 5 {
        updatedRecordsByIdempotencyKey[idempotencyKey] = updated
      } else {
        completedIdempotencyKeys.insert(idempotencyKey)
        SiriShortcutDiagnostics.record(
          source: "native",
          action: "wallet-pending-sync-dropped",
          message: "Dropping pending wallet capture after repeated sync failures.",
          details: [
            "error": error.localizedDescription,
            "attemptCount": updated["attemptCount"] as? Int ?? 0,
          ]
        )
      }
    }
  }

  let remainingCount = mergePendingWalletCaptureSyncResults(
    completedIdempotencyKeys: completedIdempotencyKeys,
    updatedRecordsByIdempotencyKey: updatedRecordsByIdempotencyKey
  )
  SiriShortcutDiagnostics.record(
    source: "native",
    action: "wallet-pending-sync-finished",
    message: "Pending wallet capture sync finished.",
    details: [
      "attempted": attempted,
      "synced": synced,
      "remaining": remainingCount,
    ]
  )

  return [
    "attempted": attempted,
    "synced": synced,
    "remaining": remainingCount,
  ]
}

@available(iOS 16.0, watchOS 9.0, *)
private func performWalletPaymentIntegrationCapture(
  merchantName: String?,
  amount: Double?
) async throws -> String {
  SiriShortcutDiagnostics.record(
    source: "shortcut",
    action: "wallet-perform-start",
    message: "Wallet shortcut execution started.",
    details: [
      "merchant": merchantName ?? "",
      "amount": amount ?? -1,
    ]
  )
  NSLog(
    "[MonekoCap] performWalletPaymentIntegrationCapture called — merchant=%@, amount=%@",
    merchantName ?? "<nil>",
    amount.map(String.init(describing:)) ?? "<nil>"
  )

  guard let amount, amount > 0 else {
    NSLog("[MonekoCap] invalidInput — amount missing or <= 0")
    SiriShortcutDiagnostics.record(
      source: "shortcut",
      action: "wallet-invalid-amount",
      message: "Wallet shortcut rejected an invalid amount.",
      details: [
        "amount": amount ?? -1,
      ]
    )
    throw SiriShortcutIntentError.invalidInput
  }

  let normalizedMerchantName = merchantName?
    .trimmingCharacters(in: .whitespacesAndNewlines)
  let resolvedMerchantName = normalizedMerchantName

  guard let resolvedMerchantName, !resolvedMerchantName.isEmpty else {
    NSLog("[MonekoCap] invalidInput — no usable merchant value")
    SiriShortcutDiagnostics.record(
      source: "shortcut",
      action: "wallet-invalid-merchant",
      message: "Wallet shortcut rejected an empty merchant name."
    )
    throw SiriShortcutIntentError.invalidInput
  }

  guard var context = SiriShortcutAuthContext.load() else {
    NSLog("[MonekoCap] notConfigured — SiriShortcutAuthContext.load() returned nil")
    SiriShortcutDiagnostics.record(
      source: "shortcut",
      action: "wallet-auth-missing",
      message: "Wallet shortcut could not load shared auth context."
    )
    throw SiriShortcutIntentError.notConfigured
  }
  NSLog("[MonekoCap] Auth context loaded — userId=%@, tokenExpired=%d", context.userId, context.isAccessTokenExpired ? 1 : 0)

  guard let scope = loadWalletCaptureScope(expectedUserId: context.userId) else {
    NSLog("[MonekoCap] notConfigured — loadWalletCaptureScope() returned nil")
    SiriShortcutDiagnostics.record(
      source: "shortcut",
      action: "wallet-scope-missing",
      message: "Wallet shortcut could not load an enabled capture scope."
    )
    throw SiriShortcutIntentError.notConfigured
  }
  NSLog("[MonekoCap] Wallet scope loaded — householdId=%@", scope.householdId ?? "<personal>")
  let accountId = loadWalletCaptureAccountId()

  let idempotencyKey = makeWalletIdempotencyKey(
    userId: context.userId,
    merchantName: resolvedMerchantName,
    amount: amount,
    currencyCode: nil,
    transactionDate: nil,
    scope: scope
  )
  if !reserveWalletIdempotencySlot(idempotencyKey: idempotencyKey) {
    SiriShortcutDiagnostics.record(
      source: "shortcut",
      action: "wallet-duplicate-request",
      message: "Wallet shortcut request matched an existing idempotency slot.",
      details: [
        "idempotencyKey": idempotencyKey,
      ]
    )
    return "That wallet transaction was already captured in Moneko."
  }

  var shouldKeepIdempotencySlot = false
  defer {
    if !shouldKeepIdempotencySlot {
      clearWalletIdempotencySlot(idempotencyKey: idempotencyKey)
    }
  }

  let body = makeWalletCaptureRequestBody(
    userId: context.userId,
    idempotencyKey: idempotencyKey,
    merchantName: resolvedMerchantName,
    amount: amount,
    scope: scope,
    accountId: accountId
  )

  do {
    if context.isAccessTokenExpired {
      NSLog("[MonekoCap] Access token expired, refreshing…")
      SiriShortcutDiagnostics.record(
        source: "shortcut",
        action: "wallet-refresh-needed",
        message: "Wallet shortcut detected an expired access token.",
        details: [
          "expiresAt": context.expiresAt,
        ]
      )
      context = try await refreshSiriShortcutSession(context: context)
      context.persist()
      NSLog("[MonekoCap] Token refreshed successfully, new expiresAt=%d", context.expiresAt)
    }

    let isDuplicate = try await submitWalletCaptureRequestBody(body, context: context)
    shouldKeepIdempotencySlot = true
    if isDuplicate {
      return "That wallet transaction was already captured in Moneko."
    }
  } catch SiriShortcutIntentError.networkFailure {
    let wasQueued = enqueuePendingWalletCapture(
      body: body,
      idempotencyKey: idempotencyKey,
      userId: context.userId,
      merchantName: resolvedMerchantName,
      amount: amount
    )
    guard wasQueued else {
      throw SiriShortcutIntentError.offlineSaveFailed
    }
    shouldKeepIdempotencySlot = true
    return "Saved this Apple Pay transaction in Moneko. It will sync automatically the next time you open the app with internet."
  }

  let formattedAmount = String(format: "%.2f", amount)
  SiriShortcutDiagnostics.record(
    source: "shortcut",
    action: "wallet-success",
    message: "Wallet transaction captured successfully.",
    details: [
      "merchant": resolvedMerchantName,
      "amount": amount,
      "scope": scope.householdId ?? "personal",
    ]
  )
  return "Captured \(formattedAmount) at \(resolvedMerchantName) in Moneko."
}

@available(iOS 16.0, watchOS 9.0, *)
struct CaptureWalletTransactionIntent: AppIntent {
  static var title: LocalizedStringResource = "capture_wallet_transaction_title"
  static var description = IntentDescription("Capture a wallet transaction in Moneko using the merchant and amount from Shortcuts.")

  @available(*, deprecated, message: "Use supportedModes when available.")
  static var openAppWhenRun: Bool { false }

  @Parameter(
    title: "Merchant",
    requestValueDialog: IntentDialog("Where did you spend?")
  )
  var merchantName: String?

  @Parameter(
    title: "Amount",
    requestValueDialog: IntentDialog("How much did you spend?")
  )
  var amount: Double?

  func perform() async throws -> some IntentResult & ProvidesDialog {
    do {
      let message = try await performWalletPaymentIntegrationCapture(
        merchantName: merchantName,
        amount: amount
      )
      return .result(dialog: IntentDialog(stringLiteral: message))
    } catch let intentError as SiriShortcutIntentError {
      let dialogMessage = intentError.errorDescription ??
        "Wallet capture failed. Please open Moneko and try again."
      SiriShortcutDiagnostics.record(
        source: "shortcut",
        action: "wallet-intent-error",
        message: "Wallet shortcut finished with a handled intent error.",
        details: [
          "error": String(describing: intentError),
          "description": dialogMessage,
        ]
      )
      return .result(
        dialog: IntentDialog(
          stringLiteral: dialogMessage
        )
      )
    } catch {
      let rawMessage = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
      let fallbackMessage = String(describing: error).trimmingCharacters(in: .whitespacesAndNewlines)
      let dialogMessage = !rawMessage.isEmpty
        ? "Wallet capture failed: \(rawMessage)"
        : !fallbackMessage.isEmpty
          ? "Wallet capture failed: \(fallbackMessage)"
          : "Wallet capture failed unexpectedly. Open Moneko > Apple Pay Integration > Debug report."
      SiriShortcutDiagnostics.record(
        source: "shortcut",
        action: "wallet-intent-unexpected-error",
        message: "Wallet shortcut finished with an unexpected error.",
        details: [
          "error": !rawMessage.isEmpty ? rawMessage : fallbackMessage,
          "type": String(describing: type(of: error)),
        ]
      )
      return .result(
        dialog: IntentDialog(
          stringLiteral: dialogMessage
        )
      )
    }
  }
}


private enum SiriShortcutKeys {
  static let appGroupId = "group.moneko.mobile"
  static let supabaseUrl = "siri_supabase_url"
  static let supabaseAnonKey = "siri_supabase_anon_key"

  static let keychainService = "com.moneko.mobile.siri-shortcut-auth"
  // Shared keychain access group — must match the keychain-access-groups entitlement.
  // $(AppIdentifierPrefix) expands to the Team ID at build time; at runtime use the literal value.
  static let keychainAccessGroup = "GW28HYRJ9H.group.moneko.mobile"
  static let accessTokenAccount = "access_token"
  static let refreshTokenAccount = "refresh_token"
  static let userIdAccount = "user_id"
  static let expiresAtAccount = "expires_at"

  static let idempotencyHash = "siri_last_request_hash"
  static let idempotencyTimestamp = "siri_last_request_at"

  static let walletCaptureEnabled = "wallet_capture_enabled"
  static let walletDefaultScopeId = "wallet_default_scope_id"
  static let walletDefaultScopeName = "wallet_default_scope_name"
  static let walletDefaultIsPortfolio = "wallet_default_is_portfolio"
  static let walletDefaultAccountId = "wallet_default_account_id"
  static let walletDefaultAccountName = "wallet_default_account_name"
  static let walletConfigUserId = "wallet_config_user_id"
  static let walletIdempotencyHash = "wallet_last_request_hash"
  static let walletIdempotencyTimestamp = "wallet_last_request_at"
  static let walletDebugEntries = "wallet_capture_debug_entries"
  static let walletPendingCaptures = "wallet_pending_captures"
}

private func makeDiagnosticsTimestamp() -> String {
  let formatter = ISO8601DateFormatter()
  formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
  return formatter.string(from: Date())
}

private func sanitizeDiagnosticsValue(_ value: Any) -> Any {
  switch value {
  case let string as String:
    return string
  case let number as NSNumber:
    return number
  case let bool as Bool:
    return bool
  case let dictionary as [String: Any]:
    return dictionary.mapValues(sanitizeDiagnosticsValue)
  case let array as [Any]:
    return array.map(sanitizeDiagnosticsValue)
  default:
    return String(describing: value)
  }
}

private func truncateDiagnosticsBody(_ value: String, limit: Int = 500) -> String {
  guard value.count > limit else {
    return value
  }
  return "\(value.prefix(limit))…"
}

private func diagnosticsStatusDescription(_ status: OSStatus) -> String {
  if let message = SecCopyErrorMessageString(status, nil) as String? {
    return message
  }
  return "OSStatus(\(status))"
}

private enum SiriShortcutDiagnostics {
  static let maxEntries = 80

  static func record(
    source: String,
    action: String,
    message: String,
    details: [String: Any] = [:]
  ) {
    NSLog("[MonekoDebug][%@/%@] %@ %@", source, action, message, String(describing: details))

    guard let defaults = UserDefaults(suiteName: SiriShortcutKeys.appGroupId) else {
      return
    }

    let sanitizedDetails = details.mapValues(sanitizeDiagnosticsValue)
    var entry: [String: Any] = [
      "timestamp": makeDiagnosticsTimestamp(),
      "source": source,
      "action": action,
      "message": message,
    ]
    if !sanitizedDetails.isEmpty {
      entry["details"] = sanitizedDetails
    }

    var entries = (defaults.array(forKey: SiriShortcutKeys.walletDebugEntries) as? [[String: Any]]) ?? []
    entries.append(entry)
    if entries.count > maxEntries {
      entries = Array(entries.suffix(maxEntries))
    }
    defaults.set(entries, forKey: SiriShortcutKeys.walletDebugEntries)
  }

  static func clear() {
    guard let defaults = UserDefaults(suiteName: SiriShortcutKeys.appGroupId) else {
      return
    }
    defaults.removeObject(forKey: SiriShortcutKeys.walletDebugEntries)
  }

  static func entries() -> [[String: Any]] {
    guard let defaults = UserDefaults(suiteName: SiriShortcutKeys.appGroupId) else {
      return []
    }
    return (defaults.array(forKey: SiriShortcutKeys.walletDebugEntries) as? [[String: Any]]) ?? []
  }

  static func snapshot() -> [String: Any] {
    let defaults = UserDefaults(suiteName: SiriShortcutKeys.appGroupId)
    let context = SiriShortcutAuthContext.load(logFailure: false)

    let hasSupabaseUrl = ((defaults?.string(forKey: SiriShortcutKeys.supabaseUrl) ?? "").isEmpty == false)
    let hasSupabaseAnon = ((defaults?.string(forKey: SiriShortcutKeys.supabaseAnonKey) ?? "").isEmpty == false)
    let hasAccessToken = ((SharedKeychainStore.shared.read(account: SiriShortcutKeys.accessTokenAccount, logFailure: false) ?? "").isEmpty == false)
    let hasRefreshToken = ((SharedKeychainStore.shared.read(account: SiriShortcutKeys.refreshTokenAccount, logFailure: false) ?? "").isEmpty == false)
    let hasUserId = ((SharedKeychainStore.shared.read(account: SiriShortcutKeys.userIdAccount, logFailure: false) ?? "").isEmpty == false)

    return [
      "hasSupabaseConfig": hasSupabaseUrl && hasSupabaseAnon,
      "hasCredentials": hasAccessToken && hasRefreshToken && hasUserId,
      "isReady": hasSupabaseUrl && hasSupabaseAnon && hasAccessToken && hasRefreshToken && hasUserId,
      "walletCaptureEnabled": defaults?.bool(forKey: SiriShortcutKeys.walletCaptureEnabled) ?? false,
      "walletScopeId": defaults?.string(forKey: SiriShortcutKeys.walletDefaultScopeId) ?? "personal",
      "walletScopeName": defaults?.string(forKey: SiriShortcutKeys.walletDefaultScopeName) ?? "Personal",
      "walletIsPortfolio": defaults?.bool(forKey: SiriShortcutKeys.walletDefaultIsPortfolio) ?? false,
      "walletAccountId": defaults?.string(forKey: SiriShortcutKeys.walletDefaultAccountId) ?? "",
      "walletAccountName": defaults?.string(forKey: SiriShortcutKeys.walletDefaultAccountName) ?? "",
      "pendingWalletCaptures": loadPendingWalletCaptureRecords().count,
      "expiresAt": context?.expiresAt ?? 0,
      "isAccessTokenExpired": context?.isAccessTokenExpired ?? false,
    ]
  }

  static func report() -> [String: Any] {
    [
      "snapshot": snapshot(),
      "entries": entries(),
    ]
  }
}

private struct SiriShortcutScopeResolution {
  let householdId: String?
  let isPortfolio: Bool
}

private struct SiriShortcutResolvedIntentInput {
  let expenseText: String
  let scope: SiriShortcutScopeResolution
}

private struct SiriShortcutStoredSpace {
  let id: String
  let name: String
  let isPortfolio: Bool

  var isPersonal: Bool {
    id == "personal"
  }
}

private func loadStoredSpaces() -> [SiriShortcutStoredSpace] {
  var spaces = [
    SiriShortcutStoredSpace(id: "personal", name: "Personal", isPortfolio: false)
  ]

  guard let defaults = UserDefaults(suiteName: SiriShortcutKeys.appGroupId),
        let json = defaults.string(forKey: "config_households"),
        let data = json.data(using: .utf8),
        let list = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
    return spaces
  }

  for item in list {
    let id = (item["id"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    let name = (item["name"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    guard !id.isEmpty, !name.isEmpty else {
      continue
    }

    let storedSpace = SiriShortcutStoredSpace(
      id: id,
      name: name,
      isPortfolio: item["isPortfolio"] as? Bool ?? false
    )

    if storedSpace.isPersonal {
      spaces[0] = storedSpace
      continue
    }

    spaces.append(storedSpace)
  }

  return spaces
}

private func normalizeScopeLookupValue(
  _ rawValue: String,
  stripTrailingKeywords: Bool = false
) -> String {
  let folded = rawValue.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
  let sanitized = String(
    folded.unicodeScalars.map { scalar in
      CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : " "
    }
  )

  var normalized = sanitized
    .components(separatedBy: .whitespacesAndNewlines)
    .filter { !$0.isEmpty }
    .joined(separator: " ")

  if stripTrailingKeywords {
    for suffix in [" space", " account"] {
      if normalized.hasSuffix(suffix) {
        normalized.removeLast(suffix.count)
        normalized = normalized.trimmingCharacters(in: .whitespacesAndNewlines)
      }
    }
  }

  return normalized
}

@available(iOS 16.0, watchOS 9.0, *)
private func detectSiriInputLanguage(for text: String) -> String {
  let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
  guard !trimmed.isEmpty else {
    return fallbackSiriLanguageCode()
  }

  let recognizer = NLLanguageRecognizer()
  recognizer.processString(trimmed)

  if let dominantLanguage = recognizer.dominantLanguage,
     dominantLanguage != .undetermined {
    return dominantLanguage.rawValue
  }

  return fallbackSiriLanguageCode()
}

private func fallbackSiriLanguageCode() -> String {
  if let preferredLanguage = Locale.preferredLanguages.first {
    let normalizedPreferredLanguage = preferredLanguage
      .split(whereSeparator: { $0 == "-" || $0 == "_" })
      .first
    if let normalizedPreferredLanguage {
      let languageCode = String(normalizedPreferredLanguage).lowercased()
      if languageCode.count == 2 {
        return languageCode
      }
    }
  }

  let localeLanguage = Locale.current.identifier
    .split(whereSeparator: { $0 == "-" || $0 == "_" })
    .first
  if let localeLanguage {
    let languageCode = String(localeLanguage).lowercased()
    if languageCode.count == 2 {
      return languageCode
    }
  }

  return "en"
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

  static func load(logFailure: Bool = true) -> SiriShortcutAuthContext? {
    guard let defaults = UserDefaults(suiteName: SiriShortcutKeys.appGroupId) else {
      if logFailure {
        SiriShortcutDiagnostics.record(
          source: "native",
          action: "auth-load-missing-defaults",
          message: "Unable to open shared app group defaults."
        )
      }
      return nil
    }

    let supabaseUrl = (defaults.string(forKey: SiriShortcutKeys.supabaseUrl) ?? "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    let supabaseAnonKey = (defaults.string(forKey: SiriShortcutKeys.supabaseAnonKey) ?? "")
      .trimmingCharacters(in: .whitespacesAndNewlines)

    let accessToken = (SharedKeychainStore.shared.read(account: SiriShortcutKeys.accessTokenAccount, logFailure: logFailure) ?? "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    let refreshToken = (SharedKeychainStore.shared.read(account: SiriShortcutKeys.refreshTokenAccount, logFailure: logFailure) ?? "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    let userId = (SharedKeychainStore.shared.read(account: SiriShortcutKeys.userIdAccount, logFailure: logFailure) ?? "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    let expiresAtValue = (SharedKeychainStore.shared.read(account: SiriShortcutKeys.expiresAtAccount, logFailure: false) ?? "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    let expiresAt = Int(expiresAtValue) ?? 0

    guard !supabaseUrl.isEmpty,
          !supabaseAnonKey.isEmpty,
          !accessToken.isEmpty,
          !refreshToken.isEmpty,
          !userId.isEmpty else {
      if logFailure {
        SiriShortcutDiagnostics.record(
          source: "native",
          action: "auth-load-incomplete",
          message: "Shared Siri auth context is incomplete.",
          details: [
            "hasSupabaseUrl": !supabaseUrl.isEmpty,
            "hasSupabaseAnonKey": !supabaseAnonKey.isEmpty,
            "hasAccessToken": !accessToken.isEmpty,
            "hasRefreshToken": !refreshToken.isEmpty,
            "hasUserId": !userId.isEmpty,
            "expiresAt": expiresAt,
          ]
        )
      }
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
      SiriShortcutDiagnostics.record(
        source: "native",
        action: "auth-persist-missing-defaults",
        message: "Unable to persist shared auth context because app group defaults are unavailable."
      )
      return
    }
    defaults.set(supabaseUrl, forKey: SiriShortcutKeys.supabaseUrl)
    defaults.set(supabaseAnonKey, forKey: SiriShortcutKeys.supabaseAnonKey)

    SharedKeychainStore.shared.write(value: accessToken, account: SiriShortcutKeys.accessTokenAccount)
    SharedKeychainStore.shared.write(value: refreshToken, account: SiriShortcutKeys.refreshTokenAccount)
    SharedKeychainStore.shared.write(value: userId, account: SiriShortcutKeys.userIdAccount)
    SharedKeychainStore.shared.write(value: String(expiresAt), account: SiriShortcutKeys.expiresAtAccount)

    SiriShortcutDiagnostics.record(
      source: "native",
      action: "auth-persisted",
      message: "Persisted refreshed Siri shortcut credentials.",
      details: [
        "userId": userId,
        "expiresAt": expiresAt,
      ]
    )
  }
}

private final class SharedKeychainStore {
  static let shared = SharedKeychainStore()

  private func baseQuery(account: String) -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: SiriShortcutKeys.keychainService,
      kSecAttrAccount as String: account,
      kSecAttrAccessGroup as String: SiriShortcutKeys.keychainAccessGroup,
    ]
  }

  func read(account: String, logFailure: Bool = true) -> String? {
    var query = baseQuery(account: account)
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne

    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    if status == errSecItemNotFound {
      return nil
    }
    guard status == errSecSuccess,
          let data = item as? Data,
          let value = String(data: data, encoding: .utf8) else {
      if logFailure {
        SiriShortcutDiagnostics.record(
          source: "native",
          action: "keychain-read-failed",
          message: "Failed to read shared keychain item.",
          details: [
            "account": account,
            "status": Int(status),
            "statusMessage": diagnosticsStatusDescription(status),
          ]
        )
      }
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
      SiriShortcutDiagnostics.record(
        source: "native",
        action: "keychain-write-updated",
        message: "Updated shared keychain item.",
        details: [
          "account": account,
          "length": data.count,
        ]
      )
      return
    }

    var addQuery = query
    addQuery[kSecValueData as String] = data
    addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
    if addStatus == errSecSuccess {
      SiriShortcutDiagnostics.record(
        source: "native",
        action: "keychain-write-added",
        message: "Added shared keychain item.",
        details: [
          "account": account,
          "length": data.count,
        ]
      )
      return
    }

    SiriShortcutDiagnostics.record(
      source: "native",
      action: "keychain-write-failed",
      message: "Unable to store shared keychain item.",
      details: [
        "account": account,
        "updateStatus": Int(updateStatus),
        "updateMessage": diagnosticsStatusDescription(updateStatus),
        "addStatus": Int(addStatus),
        "addMessage": diagnosticsStatusDescription(addStatus),
      ]
    )
  }

  func delete(account: String) {
    let query = baseQuery(account: account)
    let status = SecItemDelete(query as CFDictionary)
    if status == errSecSuccess || status == errSecItemNotFound {
      return
    }
    SiriShortcutDiagnostics.record(
      source: "native",
      action: "keychain-delete-failed",
      message: "Unable to delete shared keychain item.",
      details: [
        "account": account,
        "status": Int(status),
        "statusMessage": diagnosticsStatusDescription(status),
      ]
    )
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
  case offlineSaveFailed
  case saveFailed
  case requestFailed
  case backendError(message: String, code: String?)

  var errorDescription: String? {
    switch self {
    case .notConfigured:
      return "Turn on Apple Pay syncing in your Moneko Settings to continue."
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
    case .offlineSaveFailed:
      return "Moneko could not save this transaction offline. Please open the app and try again."
    case .saveFailed:
      return "I analyzed the expense, but failed to save it. Please try again."
    case .requestFailed:
      return "I could not complete that request in Moneko. Please try again."
    case let .backendError(message, _):
      return message
    }
  }
}

@available(iOS 16.0, watchOS 9.0, *)
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
    let message = try await performSiriTransactionLogging(
      text: expenseText,
      currencyCode: currencyCode,
      scopeName: scopeName,
      typeHint: "expense"
    )
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
      "language": detectSiriInputLanguage(for: text),
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
    if (200...299).contains(httpResponse.statusCode) {
      do {
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let succeeded = extractSucceededCount(from: json),
           succeeded > 0 {
          return succeeded
        }
      } catch {
        throw SiriShortcutIntentError.saveFailed
      }

      throw SiriShortcutIntentError.saveFailed
    }

    if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
      throw SiriShortcutIntentError.missingSession
    }

    if httpResponse.statusCode == 409 {
      throw SiriShortcutIntentError.duplicateRequest
    }

    if httpResponse.statusCode == 429 {
      throw SiriShortcutIntentError.networkFailure
    }

    if httpResponse.statusCode == 404 {
      let fallbackCount = try await persistTransactionsIndividually(
        transactions: transactions,
        scope: scope,
        context: context,
        idempotencyKey: idempotencyKey
      )
      if fallbackCount > 0 {
        return fallbackCount
      }
    }
    throw SiriShortcutIntentError.saveFailed
  }

  private func extractSucceededCount(from json: [String: Any]) -> Int? {
    if let summary = json["summary"] as? [String: Any],
       let succeeded = parseSucceededValue(summary["succeeded"]) {
      return succeeded
    }

    if let dataObject = json["data"] as? [String: Any],
       let summary = dataObject["summary"] as? [String: Any],
       let succeeded = parseSucceededValue(summary["succeeded"]) {
      return succeeded
    }

    if let results = json["results"] as? [[String: Any]] {
      return results.reduce(into: 0) { count, item in
        if (item["success"] as? Bool) == true {
          count += 1
        }
      }
    }

    return nil
  }

  private func parseSucceededValue(_ value: Any?) -> Int? {
    if let intValue = value as? Int {
      return intValue
    }
    if let numberValue = value as? NSNumber {
      return numberValue.intValue
    }
    if let stringValue = value as? String,
       let intValue = Int(stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) {
      return intValue
    }
    return nil
  }

  private func persistTransactionsIndividually(
    transactions: [[String: Any]],
    scope: SiriShortcutScopeResolution,
    context: SiriShortcutAuthContext,
    idempotencyKey: String
  ) async throws -> Int {
    var savedCount = 0

    for (index, transaction) in transactions.enumerated() {
      let normalizedType = ((transaction["type"] as? String) ?? "expense").lowercased()
      let endpoint = normalizedType == "income" ? "save-income" : "save-expense"

      guard let url = URL(string: "\(context.supabaseUrl)/functions/v1/\(endpoint)") else {
        continue
      }

      var request = URLRequest(url: url)
      request.httpMethod = "POST"
      request.timeoutInterval = 25
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.setValue("Bearer \(context.accessToken)", forHTTPHeaderField: "Authorization")
      request.setValue(context.supabaseAnonKey, forHTTPHeaderField: "apikey")
      request.setValue("\(idempotencyKey)-\(index)", forHTTPHeaderField: "x-idempotency-key")

      var body: [String: Any] = [
        "userId": context.userId,
      ]
      for (key, value) in transaction {
        if key == "type" {
          continue
        }
        body[key] = value
      }
      if let householdId = scope.householdId {
        body["householdId"] = householdId
        body["isPortfolio"] = scope.isPortfolio
      }

      request.httpBody = try JSONSerialization.data(withJSONObject: body)

      do {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
          continue
        }

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
          throw SiriShortcutIntentError.missingSession
        }

        guard (200...299).contains(httpResponse.statusCode) else {
          continue
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
          continue
        }

        if json["id"] != nil {
          savedCount += 1
          continue
        }

        if let dataObject = json["data"] as? [String: Any], dataObject["id"] != nil {
          savedCount += 1
        }
      } catch let intentError as SiriShortcutIntentError {
        throw intentError
      } catch {
        continue
      }
    }

    return savedCount
  }

  private func buildBatchTransactions(from items: [[String: Any]]) -> [[String: Any]] {
    let isoTimestamp = ISO8601DateFormatter().string(from: Date())
    var transactions: [[String: Any]] = []

    for item in items {
      let amountValue: Double
      if let numberValue = item["amount"] as? NSNumber {
        amountValue = numberValue.doubleValue
      } else if let stringValue = item["amount"] as? String,
                let parsedValue = Double(stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) {
        amountValue = parsedValue
      } else {
        amountValue = -1
      }

      guard
        amountValue > 0,
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
        "amount": amountValue,
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

  private func resolveIntentInput(
    expenseText: String,
    scopeName: String?
  ) -> SiriShortcutResolvedIntentInput {
    let explicitScope = resolveScope(scopeName)
    if explicitScope.householdId != nil {
      return SiriShortcutResolvedIntentInput(expenseText: expenseText, scope: explicitScope)
    }

    guard let extractedInput = extractScopeFromExpenseText(expenseText) else {
      return SiriShortcutResolvedIntentInput(expenseText: expenseText, scope: explicitScope)
    }

    return extractedInput
  }

  private func resolveScope(_ rawValue: String?) -> SiriShortcutScopeResolution {
    let fallback = SiriShortcutScopeResolution(householdId: nil, isPortfolio: false)
    guard let rawValue else { return fallback }
    let normalized = normalizeScopeLookupValue(rawValue)
    let strippedNormalized = normalizeScopeLookupValue(rawValue, stripTrailingKeywords: true)
    if normalized.isEmpty || normalized == "personal" {
      return fallback
    }

    var strippedMatches: [SiriShortcutScopeResolution] = []

    for space in loadStoredSpaces() {
      if space.isPersonal {
        continue
      }
      let exactResolution = SiriShortcutScopeResolution(
        householdId: space.id,
        isPortfolio: space.isPortfolio
      )
      let normalizedId = normalizeScopeLookupValue(space.id)
      let normalizedName = normalizeScopeLookupValue(space.name)
      if normalized == normalizedId || normalized == normalizedName {
        return exactResolution
      }
      if strippedNormalized != normalized &&
        (strippedNormalized == normalizedId || strippedNormalized == normalizedName) {
        strippedMatches.append(exactResolution)
      }
    }

    if strippedMatches.count == 1 {
      return strippedMatches[0]
    }

    return fallback
  }

  private func extractScopeFromExpenseText(
    _ rawText: String
  ) -> SiriShortcutResolvedIntentInput? {
    let spaces = loadStoredSpaces()
      .filter { !$0.isPersonal }
      .sorted { $0.name.count > $1.name.count }
    guard !spaces.isEmpty else {
      return nil
    }

    for space in spaces {
      let nameVariants = [
        space.name,
        space.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
      ]
      let escapedNamePattern = Set(nameVariants)
        .map(NSRegularExpression.escapedPattern(for:))
        .joined(separator: "|")
      let pattern = "\\s+(?:in|into|under)\\s+(?:(?:the|my)\\s+)?(?:\(escapedNamePattern))(?:\\s+(?:space|account))?[\\p{P}\\s]*$"
      guard let regex = try? NSRegularExpression(
        pattern: pattern,
        options: [.caseInsensitive]
      ) else {
        continue
      }

      let fullRange = NSRange(rawText.startIndex..<rawText.endIndex, in: rawText)
      guard let match = regex.firstMatch(in: rawText, options: [], range: fullRange),
            let matchRange = Range(match.range, in: rawText) else {
        continue
      }

      let cleanedText = rawText[..<matchRange.lowerBound]
        .trimmingCharacters(in: .whitespacesAndNewlines)
      guard !cleanedText.isEmpty else {
        continue
      }

      return SiriShortcutResolvedIntentInput(
        expenseText: cleanedText,
        scope: SiriShortcutScopeResolution(
          householdId: space.id,
          isPortfolio: space.isPortfolio
        )
      )
    }

    return nil
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

  private func makeIdempotencyKey(
    userId: String,
    text: String,
    scope: SiriShortcutScopeResolution
  ) -> String {
    let normalizedText = text
      .lowercased()
      .components(separatedBy: .whitespacesAndNewlines)
      .filter { !$0.isEmpty }
      .joined(separator: " ")
    let scopeKey = scope.householdId ?? "personal"
    let minuteBucket = Int(Date().timeIntervalSince1970 / 60)
    let raw = "\(userId)|\(scopeKey)|\(normalizedText)|\(minuteBucket)"
    let digest = SHA256.hash(data: Data(raw.utf8))
    return digest.map { String(format: "%02x", $0) }.joined()
  }
}

@available(iOS 16.0, watchOS 9.0, *)
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
    AppShortcut(
      intent: LogIncomeWithSiriIntent(),
      phrases: [
        "Log income with \(.applicationName)",
        "Add income in \(.applicationName)"
      ],
      shortTitle: "Log Income",
      systemImageName: "arrow.down.circle.fill"
    )
    AppShortcut(
      intent: SetBudgetWithSiriIntent(),
      phrases: [
        "Set budget with \(.applicationName)",
        "Create budget in \(.applicationName)"
      ],
      shortTitle: "Set Budget",
      systemImageName: "target"
    )
    AppShortcut(
      intent: CheckBudgetWithSiriIntent(),
      phrases: [
        "Check budget with \(.applicationName)",
        "Budget status in \(.applicationName)"
      ],
      shortTitle: "Check Budget",
      systemImageName: "chart.bar.xaxis"
    )
    AppShortcut(
      intent: CheckSpendingWithSiriIntent(),
      phrases: [
        "Check spending with \(.applicationName)",
        "What did I spend with \(.applicationName)"
      ],
      shortTitle: "Check Spending",
      systemImageName: "list.bullet.clipboard"
    )
    AppShortcut(
      intent: AnalyzeSpendingWithSiriIntent(),
      phrases: [
        "Analyze spending with \(.applicationName)",
        "Analyze my spending in \(.applicationName)"
      ],
      shortTitle: "Analyze Spending",
      systemImageName: "sparkles"
    )
    AppShortcut(
      intent: CaptureWalletTransactionIntent(),
      phrases: [
        "Capture wallet transaction in \(.applicationName)",
        "Run wallet transaction capture with \(.applicationName)"
      ],
      shortTitle: "capture_wallet_transaction_title",
      systemImageName: "wallet.pass.fill"
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
      case SiriShortcutChannel.getWalletCaptureDebugReport:
        self.handleGetWalletCaptureDebugReport(result: result)
      case SiriShortcutChannel.clearWalletCaptureDebugReport:
        self.handleClearWalletCaptureDebugReport(result: result)
      case SiriShortcutChannel.appendWalletCaptureDebugEntry:
        self.handleAppendWalletCaptureDebugEntry(call: call, result: result)
      case SiriShortcutChannel.syncPendingWalletCaptures:
        self.handleSyncPendingWalletCaptures(result: result)
      case "setWalletCaptureConfig":
        self.handleSetWalletCaptureConfig(call: call, result: result)
      case "getWalletCaptureConfig":
        self.handleGetWalletCaptureConfig(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func handleSyncAuthContext(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let defaults = UserDefaults(suiteName: SiriShortcutKeys.appGroupId) else {
      SiriShortcutDiagnostics.record(
        source: "flutter",
        action: "sync-auth-invalid-args",
        message: "Flutter tried to sync Siri auth context with invalid arguments."
      )
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

    SiriShortcutDiagnostics.record(
      source: "flutter",
      action: "sync-auth-complete",
      message: "Flutter synced Siri shortcut auth context.",
      details: [
        "userId": (args["userId"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
        "expiresAt": args["expiresAt"] as? Int ?? 0,
        "snapshot": SiriShortcutDiagnostics.snapshot(),
      ]
    )

    result(nil)
  }

  private func handleGetStatus(result: @escaping FlutterResult) {
    result(SiriShortcutDiagnostics.snapshot())
  }

  private func handleClearAuthContext(result: @escaping FlutterResult) {
    let defaults = UserDefaults(suiteName: SiriShortcutKeys.appGroupId)
    defaults?.removeObject(forKey: SiriShortcutKeys.supabaseUrl)
    defaults?.removeObject(forKey: SiriShortcutKeys.supabaseAnonKey)
    SharedKeychainStore.shared.clearAll()
    SiriShortcutDiagnostics.record(
      source: "flutter",
      action: "clear-auth-context",
      message: "Flutter cleared shared Siri shortcut auth context."
    )
    result(nil)
  }

  private func handleGetWalletCaptureDebugReport(result: @escaping FlutterResult) {
    result(SiriShortcutDiagnostics.report())
  }

  private func handleClearWalletCaptureDebugReport(result: @escaping FlutterResult) {
    SiriShortcutDiagnostics.clear()
    SiriShortcutDiagnostics.record(
      source: "flutter",
      action: "debug-log-cleared",
      message: "Wallet capture debug log was cleared from Flutter."
    )
    result(nil)
  }

  private func handleAppendWalletCaptureDebugEntry(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any] else {
      result(FlutterError(code: "invalid_args", message: "Invalid wallet debug entry args", details: nil))
      return
    }

    let source = (args["source"] as? String ?? "flutter").trimmingCharacters(in: .whitespacesAndNewlines)
    let action = (args["action"] as? String ?? "unknown").trimmingCharacters(in: .whitespacesAndNewlines)
    let message = (args["message"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    let details = args["details"] as? [String: Any] ?? [:]

    SiriShortcutDiagnostics.record(
      source: source.isEmpty ? "flutter" : source,
      action: action.isEmpty ? "unknown" : action,
      message: message,
      details: details
    )
    result(nil)
  }

  private func handleSyncPendingWalletCaptures(result: @escaping FlutterResult) {
    guard #available(iOS 16.0, *) else {
      result([
        "attempted": 0,
        "synced": 0,
        "remaining": 0,
      ])
      return
    }

    Task {
      let syncResult = await syncPendingWalletCaptures()
      DispatchQueue.main.async {
        result(syncResult)
      }
    }
  }

  private func handleSetWalletCaptureConfig(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let defaults = UserDefaults(suiteName: SiriShortcutKeys.appGroupId) else {
      result(FlutterError(code: "invalid_args", message: "Invalid wallet config args", details: nil))
      return
    }

    if let enabled = args["enabled"] as? Bool {
      defaults.set(enabled, forKey: SiriShortcutKeys.walletCaptureEnabled)
    }
    if let scopeId = args["scopeId"] as? String {
      defaults.set(scopeId, forKey: SiriShortcutKeys.walletDefaultScopeId)
    }
    if let scopeName = args["scopeName"] as? String {
      defaults.set(scopeName, forKey: SiriShortcutKeys.walletDefaultScopeName)
    }
    if let isPortfolio = args["isPortfolio"] as? Bool {
      defaults.set(isPortfolio, forKey: SiriShortcutKeys.walletDefaultIsPortfolio)
    }
    if let accountId = args["accountId"] as? String {
      if accountId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        defaults.removeObject(forKey: SiriShortcutKeys.walletDefaultAccountId)
      } else {
        defaults.set(accountId, forKey: SiriShortcutKeys.walletDefaultAccountId)
      }
    }
    if let accountName = args["accountName"] as? String {
      if accountName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        defaults.removeObject(forKey: SiriShortcutKeys.walletDefaultAccountName)
      } else {
        defaults.set(accountName, forKey: SiriShortcutKeys.walletDefaultAccountName)
      }
    }
    if let userId = args["userId"] as? String {
      let normalizedUserId = userId.trimmingCharacters(in: .whitespacesAndNewlines)
      if normalizedUserId.isEmpty {
        defaults.removeObject(forKey: SiriShortcutKeys.walletConfigUserId)
      } else {
        defaults.set(normalizedUserId, forKey: SiriShortcutKeys.walletConfigUserId)
      }
    }

    SiriShortcutDiagnostics.record(
      source: "flutter",
      action: "wallet-config-updated",
      message: "Flutter updated wallet capture configuration.",
      details: [
        "enabled": defaults.bool(forKey: SiriShortcutKeys.walletCaptureEnabled),
        "scopeId": defaults.string(forKey: SiriShortcutKeys.walletDefaultScopeId) ?? "personal",
        "scopeName": defaults.string(forKey: SiriShortcutKeys.walletDefaultScopeName) ?? "Personal",
        "isPortfolio": defaults.bool(forKey: SiriShortcutKeys.walletDefaultIsPortfolio),
        "accountId": defaults.string(forKey: SiriShortcutKeys.walletDefaultAccountId) ?? "",
        "accountName": defaults.string(forKey: SiriShortcutKeys.walletDefaultAccountName) ?? "",
        "ownerUserId": defaults.string(forKey: SiriShortcutKeys.walletConfigUserId) ?? "",
      ]
    )

    result(nil)
  }

  private func handleGetWalletCaptureConfig(result: @escaping FlutterResult) {
    let disabledConfig: [String: Any] = [
      "enabled": false,
      "scopeId": "personal",
      "scopeName": "Personal",
      "isPortfolio": false,
      "accountId": "",
      "accountName": "",
    ]

    guard let defaults = UserDefaults(suiteName: SiriShortcutKeys.appGroupId) else {
      result(disabledConfig)
      return
    }

    guard let userId = SiriShortcutAuthContext.load(logFailure: false)?.userId,
          walletCaptureConfigOwnerMatches(defaults: defaults, expectedUserId: userId) else {
      result(disabledConfig)
      return
    }

    let config: [String: Any] = [
      "enabled": defaults.bool(forKey: SiriShortcutKeys.walletCaptureEnabled),
      "scopeId": defaults.string(forKey: SiriShortcutKeys.walletDefaultScopeId) ?? "personal",
      "scopeName": defaults.string(forKey: SiriShortcutKeys.walletDefaultScopeName) ?? "Personal",
      "isPortfolio": defaults.bool(forKey: SiriShortcutKeys.walletDefaultIsPortfolio),
      "accountId": defaults.string(forKey: SiriShortcutKeys.walletDefaultAccountId) ?? "",
      "accountName": defaults.string(forKey: SiriShortcutKeys.walletDefaultAccountName) ?? "",
    ]
    result(config)
  }
}
