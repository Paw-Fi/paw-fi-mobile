import ActivityKit
import Flutter
import UIKit
import UserNotifications

/// ActivityKit owns presentation; the finite UIKit assertion owns execution.
/// Explicit Stop is journaled independently of system expiration.
final class AiAnalysisBackgroundBridge {
  static let taskIdentifier = "com.moneko.mobile.ai-analysis"
  private let channel: FlutterMethodChannel
  private let journal = AiAnalysisStopJournal()
  private let failures = AiAnalysisStopJournal(folderName: "ai-analysis-errors")
  private var id: String?
  private var captureId = ""
  private var userId = ""
  private var messages: [String: String] = [:]
  private var stage = "analyzing"
  private var background = false
  private var outcome: String?
  private var assertion: UIBackgroundTaskIdentifier = .invalid
  private var stopObserver: NSObjectProtocol?
  // Erased storage keeps Runner's iOS 16 deployment target intact.
  private var liveActivity: Any?
  private var activityUpdates: Task<Void, Never>?
  private var successDismissal: Task<Void, Never>?
  // Content of the delivered fallback notification, used to avoid reposting
  // identical copy on every lifecycle change and to clean it up.
  private var noticeSignature: String?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "moneko/ai_background_execution", binaryMessenger: messenger)
    endOrphanedActivities()
    stopObserver = NotificationCenter.default.addObserver(forName: .aiAnalysisStopped,
      object: nil, queue: .main) { [weak self] note in
        guard let token = note.object as? String else { return }
        self?.stopped(token)
      }
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { result(nil); return }
      do {
        if call.method == "pendingStops" { result(try self.journal.pending()); return }
        if call.method == "pendingFailures" { result(try self.failures.pending()); return }
        if call.method == "clear" { self.clearAll(); result(nil); return }
        guard let args = call.arguments as? [String: Any], let incomingId = args["id"] as? String else {
          result(FlutterError(code: "INVALID_AI_EXECUTION", message: "Missing execution identity", details: nil)); return
        }
        if call.method == "acknowledgeStop" { try self.journal.acknowledge(incomingId); result(nil); return }
        if call.method == "acknowledgeFailure" { try self.failures.acknowledge(incomingId); result(nil); return }
        switch call.method {
        case "start":
          self.successDismissal?.cancel()
          self.endExecution()
          self.endActivity()
          self.id = incomingId
          self.captureId = args["captureId"] as? String ?? ""
          self.userId = args["userId"] as? String ?? ""
          self.messages = args["messages"] as? [String: String] ?? [:]
          self.stage = "analyzing"
          self.outcome = args["outcome"] as? String
          self.background = args["background"] as? Bool ?? false
          if self.outcome == nil {
            self.assertion = UIApplication.shared.beginBackgroundTask(withName: Self.taskIdentifier) { [weak self] in
              self?.expire(incomingId)
            }
          }
          self.startActivity(args)
          self.publishIfNeeded()
          result(self.assertion != .invalid)
        case "update":
          guard self.id == incomingId, self.outcome != "cancelled" else { result(nil); return }
          self.background = args["background"] as? Bool ?? self.background
          if let stage = args["stage"] as? String, ["analyzing", "saving"].contains(stage) { self.stage = stage }
          self.updateActivity()
          self.publishIfNeeded()
          result(nil)
        case "finish":
          guard self.id == incomingId else { result(nil); return }
          self.background = args["background"] as? Bool ?? self.background
          if self.outcome != "cancelled" { self.outcome = args["outcome"] as? String ?? "paused" }
          if self.outcome == "cancelled" {
            self.successDismissal?.cancel()
            self.endExecution()
            self.endActivity()
            self.clearNotice()
            try self.failures.acknowledge(incomingId)
            self.id = nil
          } else {
            // Flutter has already checkpointed its error. If native metadata
            // storage fails, still release execution and show the error state.
            let phase = AiAnalysisPhase(outcome: self.outcome)
            if phase == .error { try? self.recordFailure() }
            // Alert once on the transition into a state that needs the user,
            // only while in-app UI cannot present it.
            self.updateActivity(alert: phase.isAttention && self.background)
            self.publishIfNeeded()
            if AiAnalysisPhase(outcome: self.outcome) == .success {
              self.dismissSuccess(incomingId)
            } else { self.endExecution() }
          }
          result(nil)
        default: result(FlutterMethodNotImplemented)
        }
      } catch {
        // Failed journal reads/writes must block replay, never certify no Stop.
        result(FlutterError(code: "AI_STOP_STORAGE", message: "Could not access analysis cancellation", details: nil))
      }
    }
  }

  deinit {
    if let stopObserver { NotificationCenter.default.removeObserver(stopObserver) }
  }

  private func startActivity(_ args: [String: Any]) {
    guard #available(iOS 17.0, *), ActivityAuthorizationInfo().areActivitiesEnabled,
      UIApplication.shared.applicationState == .active,
      let id, let capture = args["captureId"] as? String,
      let user = args["userId"] as? String, !user.isEmpty else { return }
    let attributes = AiAnalysisActivityAttributes(executionId: id, captureId: capture,
      userId: user, title: messages["title"] ?? "Moneko", stopLabel: messages["stop"] ?? "Stop")
    liveActivity = try? Activity.request(attributes: attributes,
      content: activityContent(), pushType: nil)
    // End leftover activities from a killed process without treating dismissal
    // as explicit Stop. A stopped attempt is recovered from the journal instead.
    let current = id
    Task {
      for activity in Activity<AiAnalysisActivityAttributes>.activities
        where activity.attributes.executionId != current {
        await activity.end(nil, dismissalPolicy: .immediate)
      }
    }
  }

  private func updateActivity(alert: Bool = false) {
    guard #available(iOS 17.0, *), outcome != "cancelled",
      let activity = liveActivity as? Activity<AiAnalysisActivityAttributes> else { return }
    let previous = activityUpdates
    let content = activityContent()
    // ActivityKit expands the Dynamic Island, or shows the Lock Screen
    // presentation as a banner, instead of a separate notification.
    let alertConfiguration = alert ? AlertConfiguration(
      title: LocalizedStringResource(stringLiteral: currentTitle()),
      body: LocalizedStringResource(stringLiteral: currentMessage()), sound: .default) : nil
    activityUpdates = Task {
      await previous?.value
      await activity.update(content, alertConfiguration: alertConfiguration)
    }
  }

  private func currentTitle() -> String {
    let phase = AiAnalysisPhase(outcome: outcome)
    let titleKey = phase == .loading ? "loadingTitle" : phase == .success ? "successTitle" : phase == .confirmation ? "confirmationTitle" : "errorTitle"
    return messages[titleKey] ?? messages["title"] ?? "Moneko"
  }

  private func currentMessage() -> String {
    let messageKey = AiAnalysisPhase(outcome: outcome) == .error ? "error" : outcome ?? stage
    return messages[messageKey] ?? messages["paused"] ?? ""
  }

  @available(iOS 17.0, *)
  private func activityContent() -> ActivityContent<AiAnalysisActivityAttributes.ContentState> {
    let phase = AiAnalysisPhase(outcome: outcome)
    let stop = messages["stop"] ?? "Stop"
    return ActivityContent(state: AiAnalysisActivityAttributes.ContentState(
      message: currentMessage(), phase: phase, title: currentTitle(),
      actionLabel: phase == .loading ? stop : messages["cancel"] ?? stop,
      staleTitle: messages["title"] ?? "Moneko", staleMessage: messages["paused"],
      progress: phase == .loading ? aiAnalysisStageProgress(stage) : 1),
      staleDate: phase.staleInterval.map { Date().addingTimeInterval($0) })
  }

  /// A new process owns no execution, so loading/success activities left by a
  /// terminated process are stale. Attention states remain actionable: their
  /// taps reopen the exact capture and the failure journal restores retry.
  private func endOrphanedActivities() {
    guard #available(iOS 17.0, *) else { return }
    // Snapshot synchronously so an activity started after launch is untouched.
    let orphans = Activity<AiAnalysisActivityAttributes>.activities.filter {
      !($0.content.state.phase ?? .loading).isAttention
    }
    guard !orphans.isEmpty else { return }
    Task { for activity in orphans { await activity.end(nil, dismissalPolicy: .immediate) } }
  }

  /// Removes presentation that no in-memory attempt owns, such as attention
  /// left by a previous process when the actor or AI consent changes.
  private func clearAll() {
    successDismissal?.cancel()
    endExecution()
    endActivity()
    clearNotice()
    id = nil
    outcome = nil
    guard #available(iOS 17.0, *) else { return }
    let remaining = Activity<AiAnalysisActivityAttributes>.activities
    Task { for activity in remaining { await activity.end(nil, dismissalPolicy: .immediate) } }
  }

  private func dismissSuccess(_ token: String) {
    successDismissal?.cancel()
    // Keep the activity active for five seconds: ending it with .after only
    // retains Lock Screen content, not the Dynamic Island presentation.
    successDismissal = Task { @MainActor [weak self] in
      await self?.activityUpdates?.value
      let duration = AiAnalysisPhase.success.visibleDuration!
      do { try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000)) } catch { return }
      self?.completeSuccess(token)
    }
  }

  private func completeSuccess(_ token: String) {
    guard id == token, AiAnalysisPhase(outcome: outcome) == .success else { return }
    endActivity()
    endExecution()
    clearNotice()
  }

  private func recordFailure() throws {
    guard let id, !captureId.isEmpty, !userId.isEmpty else { return }
    try failures.record(id: id, captureId: captureId, userId: userId)
  }

  private func endActivity() {
    guard #available(iOS 17.0, *), let activity = liveActivity as? Activity<AiAnalysisActivityAttributes> else { return }
    liveActivity = nil
    let previous = activityUpdates
    activityUpdates = Task { await previous?.value; await activity.end(nil, dismissalPolicy: .immediate) }
  }

  private func endExecution() {
    if assertion != .invalid {
      UIApplication.shared.endBackgroundTask(assertion)
      assertion = .invalid
    }
  }

  private func stopped(_ token: String) {
    if id == token {
      successDismissal?.cancel()
      outcome = "cancelled"
      endExecution()
      endActivity()
      clearNotice()
    }
    channel.invokeMethod("stopped", arguments: token)
  }

  private func expire(_ expectedId: String) {
    guard id == expectedId else { return }
    if AiAnalysisPhase(outcome: outcome) == .success { completeSuccess(expectedId); return }
    guard outcome == nil else { return }
    outcome = "error"
    try? recordFailure()
    endExecution()
    updateActivity(alert: background)
    channel.invokeMethod("expired", arguments: expectedId)
    publishIfNeeded()
  }

  private func clearNotice() {
    noticeSignature = nil
    UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [Self.taskIdentifier])
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.taskIdentifier])
  }

  private func publishIfNeeded() {
    guard id != nil, outcome != "cancelled", liveActivity == nil else { return }
    guard background else {
      // Visible in-app UI owns presentation; never leave an outdated
      // background notice (for example "Analyzing") in Notification Center.
      if noticeSignature != nil { clearNotice() }
      return
    }
    let phase = AiAnalysisPhase(outcome: outcome)
    let content = UNMutableNotificationContent()
    content.title = currentTitle()
    content.body = currentMessage()
    let signature = "\(phase.rawValue)\n\(content.title)\n\(content.body)"
    guard signature != noticeSignature else { return }
    noticeSignature = signature
    content.userInfo = ["monekoAiAnalysisURL": aiAnalysisOpenURL(
      executionId: id ?? "", captureId: captureId, userId: userId)?.absoluteString ?? ""]
    content.threadIdentifier = Self.taskIdentifier
    // Attention states show a silent banner once; progress and success stay passive.
    content.interruptionLevel = phase.isAttention ? .active : .passive
    let request = UNNotificationRequest(identifier: Self.taskIdentifier, content: content, trigger: nil)
    UNUserNotificationCenter.current().add(request)
  }
}
