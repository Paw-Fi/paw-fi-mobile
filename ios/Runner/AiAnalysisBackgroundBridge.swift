import BackgroundTasks
import Flutter
import UIKit
import UserNotifications

/// Holds execution only for an already-captured, user-initiated Home analysis.
/// The existing Flutter capture/outbox remains the durable source of truth.
final class AiAnalysisBackgroundBridge {
  static let taskIdentifier = "com.moneko.mobile.ai-analysis"
  private let channel: FlutterMethodChannel
  private var id: String?
  private var messages: [String: String] = [:]
  private var stage = "analyzing"
  private var background = false
  private var outcome: String?
  private var assertion: UIBackgroundTaskIdentifier = .invalid
  private var continuedTask: BGTask?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "moneko/ai_background_execution", binaryMessenger: messenger)
    if #available(iOS 26.0, *) {
      BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.taskIdentifier, using: .main) { [weak self] task in
        guard let self, let task = task as? BGContinuedProcessingTask,
              let expectedId = self.id, self.outcome == nil else {
          task.setTaskCompleted(success: false)
          return
        }
        self.continuedTask = task
        task.progress.totalUnitCount = 3
        task.progress.completedUnitCount = self.stage == "saving" ? 2 : 1
        task.expirationHandler = { [weak self] in
          DispatchQueue.main.async { self?.expire(expectedId) }
        }
        self.endAssertion()
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [Self.taskIdentifier])
      }
    }
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self, let args = call.arguments as? [String: Any],
            let incomingId = args["id"] as? String else {
        result(FlutterError(code: "INVALID_AI_EXECUTION", message: "Missing execution identity", details: nil))
        return
      }
      switch call.method {
      case "start":
        self.stopExecution(success: false)
        self.id = incomingId
        self.messages = args["messages"] as? [String: String] ?? [:]
        self.stage = "analyzing"
        self.outcome = nil
        self.background = args["background"] as? Bool ?? false
        self.assertion = UIApplication.shared.beginBackgroundTask(withName: Self.taskIdentifier) { [weak self] in
          self?.expire(incomingId)
        }
        var submitted = false
        if #available(iOS 26.0, *), UIApplication.shared.applicationState == .active {
          let request = BGContinuedProcessingTaskRequest(identifier: Self.taskIdentifier,
            title: self.messages["title"] ?? "Moneko", subtitle: self.messages["analyzing"] ?? "")
          request.strategy = .fail
          do { try BGTaskScheduler.shared.submit(request); submitted = true } catch {
            // Older/resource-limited systems retain the finite assertion only.
          }
        }
        self.publishIfNeeded()
        result(submitted || self.assertion != .invalid)
      case "update":
        guard self.id == incomingId else { result(nil); return }
        self.background = args["background"] as? Bool ?? self.background
        if let stage = args["stage"] as? String, ["analyzing", "saving"].contains(stage) {
          self.stage = stage
        }
        if #available(iOS 26.0, *), let task = self.continuedTask as? BGContinuedProcessingTask {
          task.progress.completedUnitCount = self.stage == "saving" ? 2 : 1
          task.updateTitle(self.messages["title"] ?? "Moneko", subtitle: self.messages[self.stage] ?? "")
        }
        self.publishIfNeeded()
        result(nil)
      case "finish":
        guard self.id == incomingId else { result(nil); return }
        self.background = args["background"] as? Bool ?? self.background
        let outcome = args["outcome"] as? String ?? "paused"
        self.outcome = outcome
        if #available(iOS 26.0, *), ["queued", "review"].contains(outcome),
           let task = self.continuedTask as? BGContinuedProcessingTask {
          task.progress.completedUnitCount = 3
          task.updateTitle(self.messages["title"] ?? "Moneko", subtitle: self.messages[outcome] ?? "")
        }
        self.stopExecution(success: ["queued", "needsInput", "review"].contains(outcome))
        if outcome == "cancelled" {
          self.id = nil
          UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [Self.taskIdentifier])
          UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.taskIdentifier])
        } else {
          self.publishIfNeeded()
        }
        result(nil)
      default: result(FlutterMethodNotImplemented)
      }
    }
  }

  private func endAssertion() {
    if assertion != .invalid {
      UIApplication.shared.endBackgroundTask(assertion)
      assertion = .invalid
    }
  }

  private func stopExecution(success: Bool) {
    continuedTask?.expirationHandler = nil
    continuedTask?.setTaskCompleted(success: success)
    continuedTask = nil
    if #available(iOS 26.0, *) {
      BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.taskIdentifier)
    }
    endAssertion()
  }

  private func expire(_ expectedId: String) {
    guard id == expectedId, outcome == nil else { return }
    outcome = "paused"
    stopExecution(success: false)
    channel.invokeMethod("expired", arguments: expectedId)
    publishIfNeeded()
  }

  private func publishIfNeeded() {
    guard background, id != nil else { return }
    if outcome == nil && continuedTask != nil { return }
    let content = UNMutableNotificationContent()
    content.title = messages["title"] ?? "Moneko"
    content.body = messages[outcome ?? stage] ?? messages["paused"] ?? ""
    content.interruptionLevel = .passive
    // No transaction text, amounts, question contents, badge or sound on lock screen.
    let request = UNNotificationRequest(identifier: Self.taskIdentifier, content: content, trigger: nil)
    UNUserNotificationCenter.current().add(request)
  }
}
