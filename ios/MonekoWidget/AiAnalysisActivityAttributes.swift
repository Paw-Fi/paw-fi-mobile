import ActivityKit
import AppIntents
import Foundation
import CryptoKit

enum AiAnalysisPhase: String, Codable, Hashable {
  case loading, success, error, confirmation

  init(outcome: String?) {
    switch outcome {
    case nil: self = .loading
    case "queued", "review": self = .success
    case "needsInput": self = .confirmation
    default: self = .error
    }
  }

  var visibleDuration: TimeInterval? { self == .success ? 5 : nil }
  var symbol: String {
    switch self {
    case .loading: return "sparkles"
    case .success: return "checkmark.circle.fill"
    case .error: return "exclamationmark.triangle.fill"
    case .confirmation: return "questionmark.circle.fill"
    }
  }
}

func aiAnalysisOpenURL(executionId: String, captureId: String, userId: String) -> URL? {
  var url = URLComponents()
  url.scheme = "moneko"
  url.host = "ai-analysis"
  url.queryItems = [URLQueryItem(name: "captureId", value: captureId),
    URLQueryItem(name: "userId", value: userId), URLQueryItem(name: "executionId", value: executionId)]
  return url.url
}

/// Shared by Runner and WidgetKit. Only generic copy and opaque IDs leave Flutter.
@available(iOS 17.0, *)
struct AiAnalysisActivityAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    var message: String
    var phase: AiAnalysisPhase?
    var title: String?
  }
  let executionId: String
  let captureId: String
  let userId: String
  let title: String
  let stopLabel: String

  var openURL: URL? {
    aiAnalysisOpenURL(executionId: executionId, captureId: captureId, userId: userId)
  }
}

@available(iOS 17.0, *)
struct StopAiAnalysisIntent: LiveActivityIntent {
  static var title: LocalizedStringResource = "Stop expense analysis"
  static var openAppWhenRun = false
  static var isDiscoverable = false

  @Parameter(title: "Execution") var executionId: String
  @Parameter(title: "Capture") var captureId: String
  @Parameter(title: "Owner") var userId: String

  init() {}
  init(executionId: String, captureId: String, userId: String) {
    self.executionId = executionId
    self.captureId = captureId
    self.userId = userId
  }

  func perform() async throws -> some IntentResult {
    // Persist before ending the UI or signalling Dart. A suspended/restarted
    // engine consumes this same journal before analysis or financial replay.
    try AiAnalysisStopJournal().record(id: executionId, captureId: captureId, userId: userId)
    try AiAnalysisStopJournal(folderName: "ai-analysis-errors").acknowledge(executionId)
    await MainActor.run {
      NotificationCenter.default.post(name: .aiAnalysisStopped, object: executionId)
    }
    for activity in Activity<AiAnalysisActivityAttributes>.activities
      where activity.attributes.executionId == executionId {
      await activity.end(nil, dismissalPolicy: .immediate)
    }
    return .result()
  }
}

extension Notification.Name {
  static let aiAnalysisStopped = Notification.Name("moneko.aiAnalysisStopped")
}

/// One atomic file per attempt avoids cross-process read/modify/write loss.
/// Acknowledging one stop cannot erase another stop written by an App Intent.
struct AiAnalysisStopJournal {
  private let suppliedDirectory: URL?
  private let folderName: String
  init(directory: URL? = nil, folderName: String = "ai-analysis-stops") {
    suppliedDirectory = directory
    self.folderName = folderName
  }

  private func directory() throws -> URL {
    let root: URL
    if let suppliedDirectory { root = suppliedDirectory }
    else if let group = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.moneko.mobile") {
      root = group.appendingPathComponent(folderName, isDirectory: true)
    } else { throw CocoaError(.fileNoSuchFile) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true,
      attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
    return root
  }

  private func file(_ id: String) throws -> URL {
    let key = SHA256.hash(data: Data(id.utf8)).map { String(format: "%02x", $0) }.joined()
    return try directory().appendingPathComponent(key).appendingPathExtension("json")
  }

  func record(id: String, captureId: String, userId: String) throws {
    guard !id.isEmpty, !captureId.isEmpty, !userId.isEmpty else { throw CocoaError(.coderInvalidValue) }
    let data = try JSONSerialization.data(withJSONObject: ["id": id, "captureId": captureId, "userId": userId])
    try data.write(to: file(id), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
  }

  func pending() throws -> [[String: String]] {
    try FileManager.default.contentsOfDirectory(at: directory(), includingPropertiesForKeys: nil)
      .filter { $0.pathExtension == "json" }.map { url in
        guard let record = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: String],
          let id = record["id"], !id.isEmpty,
          let capture = record["captureId"], !capture.isEmpty,
          let user = record["userId"], !user.isEmpty else { throw CocoaError(.coderReadCorrupt) }
        return record
      }
  }

  func acknowledge(_ id: String) throws {
    let url = try file(id)
    if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
  }
}
