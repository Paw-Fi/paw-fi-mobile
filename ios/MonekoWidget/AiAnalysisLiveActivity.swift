import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

@available(iOS 17.0, *)
struct AiAnalysisLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: AiAnalysisActivityAttributes.self) { context in
      HStack(spacing: 12) {
        if context.state.phase == nil || context.state.phase == .loading {
          ProgressView().controlSize(.small)
        } else {
          Image(systemName: context.state.phase!.symbol).font(.title2)
        }
        VStack(alignment: .leading, spacing: 3) {
          Text(context.state.title ?? context.attributes.title).font(.headline)
          Text(context.state.message).font(.caption).foregroundStyle(.secondary)
        }
        Spacer(minLength: 8)
        if context.state.phase != .success { stopButton(context) }
      }.padding(16).widgetURL(context.attributes.openURL)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Label(context.state.title ?? context.attributes.title,
            systemImage: (context.state.phase ?? .loading).symbol).font(.headline)
        }
        DynamicIslandExpandedRegion(.trailing) {
          if context.state.phase != .success { stopButton(context) }
        }
        DynamicIslandExpandedRegion(.bottom) {
          Text(context.state.message).font(.caption).frame(maxWidth: .infinity, alignment: .leading)
        }
      } compactLeading: {
        Image(systemName: (context.state.phase ?? .loading).symbol)
          .accessibilityLabel(context.state.title ?? context.attributes.title)
      } compactTrailing: {
        if context.state.phase == nil || context.state.phase == .loading {
          ProgressView().controlSize(.mini).accessibilityLabel(context.state.message)
        } else {
          Image(systemName: context.state.phase == .success ? "checkmark" : context.state.phase == .confirmation ? "questionmark" : "exclamationmark")
            .accessibilityLabel(context.state.message)
        }
      } minimal: {
        Image(systemName: (context.state.phase ?? .loading).symbol).accessibilityLabel(context.state.message)
      }
      .widgetURL(context.attributes.openURL)
    }
  }

  private func stopButton(_ context: ActivityViewContext<AiAnalysisActivityAttributes>) -> some View {
    Button(intent: StopAiAnalysisIntent(executionId: context.attributes.executionId,
      captureId: context.attributes.captureId, userId: context.attributes.userId)) {
      Label(context.attributes.stopLabel, systemImage: "stop.fill")
    }.buttonStyle(.bordered).controlSize(.small)
  }
}
