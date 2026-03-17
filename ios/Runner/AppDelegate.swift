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
}

@available(iOS 16.0, watchOS 9.0, *)
private struct SiriAssistantResultPayload {
  let speech: String
  let shouldOpenApp: Bool
}

@available(iOS 16.0, watchOS 9.0, *)
private func refreshSiriShortcutSession(
  context: SiriShortcutAuthContext
) async throws -> SiriShortcutAuthContext {
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

@available(iOS 16.0, watchOS 9.0, *)
private func loadWalletCaptureScope() -> SiriShortcutScopeResolution? {
  guard let defaults = UserDefaults(suiteName: SiriShortcutKeys.appGroupId) else {
    return nil
  }

  guard defaults.bool(forKey: SiriShortcutKeys.walletCaptureEnabled) else {
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
private func performWalletTransactionCapture(
  merchantName: String?,
  rawMerchant: String?,
  amount: Double?,
  currencyCode: String?,
  transactionDate: String?,
  cardLabel: String?,
  externalSourceId: String?
) async throws -> String {
  NSLog("[MonekoCap] performWalletTransactionCapture called — merchant=%@, rawMerchant=%@, amount=%@, currency=%@, date=%@, card=%@",
    merchantName ?? "<nil>", rawMerchant ?? "<nil>", amount.map { String($0) } ?? "<nil>",
    currencyCode ?? "<nil>", transactionDate ?? "<nil>", cardLabel ?? "<nil>")

  guard let amount, amount > 0 else {
    NSLog("[MonekoCap] invalidInput — amount is nil or <= 0")
    throw SiriShortcutIntentError.invalidInput
  }

  guard var context = SiriShortcutAuthContext.load() else {
    NSLog("[MonekoCap] notConfigured — SiriShortcutAuthContext.load() returned nil")
    throw SiriShortcutIntentError.notConfigured
  }
  NSLog("[MonekoCap] Auth context loaded — userId=%@, tokenExpired=%d", context.userId, context.isAccessTokenExpired ? 1 : 0)

  guard let scope = loadWalletCaptureScope() else {
    NSLog("[MonekoCap] notConfigured — loadWalletCaptureScope() returned nil")
    throw SiriShortcutIntentError.notConfigured
  }
  NSLog("[MonekoCap] Wallet scope loaded — householdId=%@", scope.householdId ?? "<personal>")

  let idempotencyKey = makeWalletIdempotencyKey(
    userId: context.userId,
    merchantName: merchantName,
    amount: amount,
    currencyCode: currencyCode,
    transactionDate: transactionDate,
    scope: scope
  )
  if !reserveWalletIdempotencySlot(idempotencyKey: idempotencyKey) {
    return "That wallet transaction was already captured in Moneko."
  }

  var shouldKeepIdempotencySlot = false
  defer {
    if !shouldKeepIdempotencySlot {
      clearWalletIdempotencySlot(idempotencyKey: idempotencyKey)
    }
  }

  if context.isAccessTokenExpired {
    NSLog("[MonekoCap] Access token expired, refreshing…")
    context = try await refreshSiriShortcutSession(context: context)
    context.persist()
    NSLog("[MonekoCap] Token refreshed successfully, new expiresAt=%d", context.expiresAt)
  }

  guard let url = URL(string: "\(context.supabaseUrl)/functions/v1/save-wallet-transaction") else {
    throw SiriShortcutIntentError.notConfigured
  }

  var request = URLRequest(url: url)
  request.httpMethod = "POST"
  request.timeoutInterval = 25
  request.setValue("application/json", forHTTPHeaderField: "Content-Type")
  request.setValue("Bearer \(context.accessToken)", forHTTPHeaderField: "Authorization")
  request.setValue(context.supabaseAnonKey, forHTTPHeaderField: "apikey")

  let normalizedCurrency: String
  if let nc = normalizeSiriCurrencyCode(currencyCode) {
    normalizedCurrency = nc
  } else if #available(iOS 16, *), let deviceCurrency = Locale.current.currency?.identifier {
    normalizedCurrency = deviceCurrency.uppercased()
    NSLog("[MonekoCap] Currency not provided, using device locale: %@", normalizedCurrency)
  } else {
    normalizedCurrency = Locale.current.currencyCode?.uppercased() ?? "USD"
    NSLog("[MonekoCap] Currency not provided, using legacy fallback: %@", normalizedCurrency)
  }

  let outputDateFormatter = DateFormatter()
  outputDateFormatter.locale = Locale(identifier: "en_US_POSIX")
  outputDateFormatter.timeZone = .current
  outputDateFormatter.dateFormat = "yyyy-MM-dd"

  let resolvedDate: String
  if let transactionDate, !transactionDate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
    let trimmedDate = transactionDate.trimmingCharacters(in: .whitespacesAndNewlines)
    // Already YYYY-MM-DD — pass through
    if trimmedDate.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil {
      resolvedDate = trimmedDate
    } else {
      // Try common date formats the Shortcut might provide
      let inputFormatter = DateFormatter()
      inputFormatter.locale = Locale(identifier: "en_US_POSIX")
      inputFormatter.timeZone = .current
      let formats = [
        "dd/MM/yyyy", "MM/dd/yyyy", "dd-MM-yyyy", "MM-dd-yyyy",
        "dd.MM.yyyy", "MM.dd.yyyy",
        "yyyy/MM/dd", "yyyy.MM.dd",
        "d/M/yyyy", "M/d/yyyy", "d-M-yyyy", "M-d-yyyy",
        "MMM d, yyyy", "d MMM yyyy", "MMMM d, yyyy", "d MMMM yyyy",
      ]
      var parsed: Date?
      for fmt in formats {
        inputFormatter.dateFormat = fmt
        if let d = inputFormatter.date(from: trimmedDate) {
          parsed = d
          break
        }
      }
      if let parsed {
        resolvedDate = outputDateFormatter.string(from: parsed)
      } else {
        // Last resort: try the system's flexible date parsing
        resolvedDate = outputDateFormatter.string(from: Date())
        NSLog("[MonekoCap] Could not parse date '%@', falling back to today", trimmedDate)
      }
    }
  } else {
    resolvedDate = outputDateFormatter.string(from: Date())
  }

  var transaction: [String: Any] = [
    "amount": amount,
    "date": resolvedDate
  ]
  if let merchantName, !merchantName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
    transaction["merchantName"] = merchantName.trimmingCharacters(in: .whitespacesAndNewlines)
  }
  if let rawMerchant, !rawMerchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
    transaction["rawMerchant"] = rawMerchant.trimmingCharacters(in: .whitespacesAndNewlines)
  }
  transaction["currency"] = normalizedCurrency
  if let cardLabel, !cardLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
    transaction["cardLabel"] = cardLabel.trimmingCharacters(in: .whitespacesAndNewlines)
  }
  if let externalSourceId, !externalSourceId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
    transaction["externalSourceId"] = externalSourceId.trimmingCharacters(in: .whitespacesAndNewlines)
  }
  // Fallback: when automation provides no merchant, add a note so the edge function
  // has at least one descriptor (it accepts merchantName | rawMerchant | note).
  if transaction["merchantName"] == nil && transaction["rawMerchant"] == nil {
    let trimmedCard = (cardLabel ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    let fallbackNote = trimmedCard.isEmpty
      ? "Apple Wallet transaction"
      : "Wallet transaction via \(trimmedCard)"
    transaction["note"] = fallbackNote
    NSLog("[MonekoCap] No merchant provided, using note fallback: %@", fallbackNote)
  }
  transaction["locale"] = Locale.current.identifier

  var body: [String: Any] = [
    "captureSource": "ios_wallet_shortcut",
    "idempotencyKey": idempotencyKey,
    "clientCreatedAt": ISO8601DateFormatter().string(from: Date()),
    "transaction": transaction
  ]
  if let householdId = scope.householdId {
    body["householdId"] = householdId
    body["isPortfolio"] = scope.isPortfolio
  }

  request.httpBody = try JSONSerialization.data(withJSONObject: body)

  NSLog("[MonekoCap] Calling save-wallet-transaction, url=%@", url.absoluteString)
  NSLog("[MonekoCap] Request body=%@", String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "<nil>")

  let data: Data
  let response: URLResponse
  do {
    (data, response) = try await URLSession.shared.data(for: request)
  } catch {
    NSLog("[MonekoCap] Network error: %@", error.localizedDescription)
    throw SiriShortcutIntentError.networkFailure
  }
  guard let httpResponse = response as? HTTPURLResponse else {
    NSLog("[MonekoCap] Response is not HTTPURLResponse")
    throw SiriShortcutIntentError.networkFailure
  }

  let responseBody = String(data: data, encoding: .utf8) ?? "<non-utf8>"
  NSLog("[MonekoCap] HTTP %d — body: %@", httpResponse.statusCode, responseBody)

  if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
    throw SiriShortcutIntentError.missingSession
  }

  if httpResponse.statusCode == 409 {
    shouldKeepIdempotencySlot = true
    return "That wallet transaction was already captured in Moneko."
  }

  guard (200...299).contains(httpResponse.statusCode) else {
    NSLog("[MonekoCap] saveFailed — non-2xx status %d", httpResponse.statusCode)
    throw SiriShortcutIntentError.saveFailed
  }

  guard
    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
    (json["success"] as? Bool) == true
  else {
    NSLog("[MonekoCap] saveFailed — response JSON missing success:true, body: %@", responseBody)
    throw SiriShortcutIntentError.saveFailed
  }

  shouldKeepIdempotencySlot = true

  if (json["duplicate"] as? Bool) == true {
    return "That wallet transaction was already captured in Moneko."
  }

  let displayMerchant = (merchantName ?? rawMerchant ?? "")
    .trimmingCharacters(in: .whitespacesAndNewlines)

  if !displayMerchant.isEmpty {
    let formattedAmount = String(format: "%.2f", amount)
    return "Captured \(formattedAmount) \(normalizedCurrency) at \(displayMerchant) in Moneko."
  }

  let formattedAmount = String(format: "%.2f", amount)
  return "Captured \(formattedAmount) \(normalizedCurrency) wallet transaction in Moneko."
}

@available(iOS 16.0, watchOS 9.0, *)
struct LogWalletTransactionIntent: AppIntent {
  static var title: LocalizedStringResource = "Log Wallet Transaction"
  static var description = IntentDescription("Automatically log a Wallet transaction in Moneko.")

  @available(*, deprecated, message: "Use supportedModes when available.")
  static var openAppWhenRun: Bool { false }

  @Parameter(title: "Merchant Name")
  var merchantName: String?

  @Parameter(title: "Raw Merchant")
  var rawMerchant: String?

  @Parameter(title: "Amount")
  var amount: Double?

  @Parameter(title: "Currency Code")
  var currencyCode: String?

  @Parameter(title: "Transaction Date")
  var transactionDate: String?

  @Parameter(title: "Card Label")
  var cardLabel: String?

  @Parameter(title: "External Source ID")
  var externalSourceId: String?

  func perform() async throws -> some IntentResult & ProvidesDialog {
    let message = try await performWalletTransactionCapture(
      merchantName: merchantName,
      rawMerchant: rawMerchant,
      amount: amount,
      currencyCode: currencyCode,
      transactionDate: transactionDate,
      cardLabel: cardLabel,
      externalSourceId: externalSourceId
    )
    return .result(dialog: IntentDialog(stringLiteral: message))
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
  static let walletIdempotencyHash = "wallet_last_request_hash"
  static let walletIdempotencyTimestamp = "wallet_last_request_at"
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
      kSecAttrAccessGroup as String: SiriShortcutKeys.keychainAccessGroup,
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
  case requestFailed

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
    case .requestFailed:
      return "I could not complete that request in Moneko. Please try again."
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
      intent: LogWalletTransactionIntent(),
      phrases: [
        "Log wallet transaction with \(.applicationName)",
        "Capture wallet payment in \(.applicationName)"
      ],
      shortTitle: "Log Wallet Transaction",
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

    result(nil)
  }

  private func handleGetWalletCaptureConfig(result: @escaping FlutterResult) {
    guard let defaults = UserDefaults(suiteName: SiriShortcutKeys.appGroupId) else {
      result([
        "enabled": false,
        "scopeId": "personal",
        "scopeName": "Personal",
        "isPortfolio": false,
      ])
      return
    }

    result([
      "enabled": defaults.bool(forKey: SiriShortcutKeys.walletCaptureEnabled),
      "scopeId": defaults.string(forKey: SiriShortcutKeys.walletDefaultScopeId) ?? "personal",
      "scopeName": defaults.string(forKey: SiriShortcutKeys.walletDefaultScopeName) ?? "Personal",
      "isPortfolio": defaults.bool(forKey: SiriShortcutKeys.walletDefaultIsPortfolio),
    ])
  }
}
