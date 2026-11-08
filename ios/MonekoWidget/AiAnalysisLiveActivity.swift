import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

@available(iOS 17.0, *)
struct AiAnalysisLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: AiAnalysisActivityAttributes.self) { context in
      AiAnalysisActivityContent(attributes: context.attributes, state: context.state,
        isStale: context.isStale)
        // Apple's standard Lock Screen Live Activity content inset.
        .padding(14)
        .widgetURL(context.attributes.openURL)
    } dynamicIsland: { context in
      let display = AiAnalysisDisplay(state: context.state, isStale: context.isStale)
      return DynamicIsland {
        // HIG: wrap content around the TrueDepth camera and keep the compact
        // glyph's position. The status glyph and action sit beside the camera;
        // text gets the full-width area below it, so nothing is pushed past
        // the expanded presentation's 160-point height limit.
        DynamicIslandExpandedRegion(.leading) {
          AiAnalysisActivityIcon(display: display)
            .accessibilityHidden(true)
            .padding(.leading, 4)
            .frame(maxHeight: .infinity)
        }
        DynamicIslandExpandedRegion(.trailing) {
          if display.phase != .success {
            AiAnalysisActionButton(attributes: context.attributes, state: context.state,
              display: display, iconOnly: true)
              .padding(.trailing, 4)
              .frame(maxHeight: .infinity)
          }
        }
        DynamicIslandExpandedRegion(.bottom) {
          AiAnalysisExpandedText(title: display.title(fallback: context.attributes.title),
            message: display.message)
        }
      } compactLeading: {
        // One status glyph is the whole compact message; no decorative
        // duplicate on the trailing side.
        AiAnalysisActivityIcon(display: display, compact: true)
          .accessibilityLabel("\(display.title(fallback: context.attributes.title)), \(display.message)")
      } compactTrailing: {
        EmptyView()
      } minimal: {
        AiAnalysisActivityIcon(display: display, compact: true)
          .accessibilityLabel(display.message)
      }
      .keylineTint(display.tint)
      // Keep WidgetKit's presentation-specific margins around the curved edges.
      .widgetURL(context.attributes.openURL)
    }
  }
}

/// Resolves what a state looks like, including loading content that outlived
/// the process that owned it.
@available(iOS 17.0, *)
private struct AiAnalysisDisplay {
  let phase: AiAnalysisPhase
  let isStale: Bool
  let state: AiAnalysisActivityAttributes.ContentState

  init(state: AiAnalysisActivityAttributes.ContentState, isStale: Bool) {
    self.state = state
    phase = state.phase ?? .loading
    self.isStale = isStale && phase == .loading
  }

  var message: String { isStale ? state.staleMessage ?? state.message : state.message }
  func title(fallback: String) -> String {
    (isStale ? state.staleTitle : nil) ?? state.title ?? fallback
  }

  var showsProgress: Bool { phase == .loading && !isStale }
  var progress: Double { min(max(state.progress ?? aiAnalysisStageProgress("analyzing"), 0), 1) }
  var symbol: String { isStale ? "pause.circle.fill" : phase.symbol }

  /// Light/dark values mirror `AppTheme` (monekoPrimary/darkPrimary,
  /// success/darkSuccess, danger/darkDanger, warning/darkWarning). The
  /// extension's global accent colour is not the brand colour.
  var tint: Color {
    if isStale { return Color("MonekoWarning") }
    switch phase {
    case .loading: return Color("MonekoBrand")
    case .success: return Color("MonekoSuccess")
    case .error: return Color("MonekoDanger")
    case .confirmation: return Color("MonekoWarning")
    }
  }
}

@available(iOS 17.0, *)
private struct AiAnalysisActivityContent: View {
  let attributes: AiAnalysisActivityAttributes
  let state: AiAnalysisActivityAttributes.ContentState
  var isStale = false
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  private var display: AiAnalysisDisplay { AiAnalysisDisplay(state: state, isStale: isStale) }

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      ViewThatFits(in: .horizontal) {
        HStack(spacing: 12) {
          heading
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
          if display.phase != .success {
            Spacer(minLength: 0)
            AiAnalysisActionButton(attributes: attributes, state: state, display: display)
              .fixedSize()
          }
        }

        // Keep the full-size title and an essential, labelled icon action in
        // one row before allowing bounded wrapping. A third row would compete
        // with the presentation's system-imposed height limit.
        HStack(spacing: 12) {
          heading.lineLimit(dynamicTypeSize.isAccessibilitySize ? 1 : 2)
          if display.phase != .success {
            Spacer(minLength: 0)
            AiAnalysisActionButton(attributes: attributes, state: state, display: display,
              iconOnly: true)
          }
        }
      }

      // Bounded by lineLimit only: forcing the ideal height would overflow,
      // and the system clips anything beyond the presentation's height.
      Text(verbatim: display.message)
        .font(.subheadline.weight(.medium))
        .foregroundStyle(.secondary)
        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 1 : 2)
        .truncationMode(.tail)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var heading: some View {
    HStack(alignment: .center, spacing: 8) {
      AiAnalysisActivityIcon(display: display)
        .accessibilityHidden(true)
      Text(verbatim: display.title(fallback: attributes.title))
        .font(.headline)
        .truncationMode(.tail)
        .layoutPriority(1)
    }
    .layoutPriority(1)
  }
}

/// Expanded Dynamic Island text below the camera. Horizontal inset keeps the
/// lines concentric with the presentation's rounded bottom corners.
@available(iOS 17.0, *)
private struct AiAnalysisExpandedText: View {
  let title: String
  let message: String
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(verbatim: title)
        .font(.headline)
        .lineLimit(1)
        .minimumScaleFactor(0.85)
      Text(verbatim: message)
        .font(.subheadline.weight(.medium))
        .foregroundStyle(.secondary)
        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 1 : 2)
        .truncationMode(.tail)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 6)
    .padding(.bottom, 2)
  }
}

/// Loading stops a running analysis; attention states cancel the capture.
/// Both use the same durable Stop journal.
@available(iOS 17.0, *)
private struct AiAnalysisActionButton: View {
  let attributes: AiAnalysisActivityAttributes
  let state: AiAnalysisActivityAttributes.ContentState
  let display: AiAnalysisDisplay
  var iconOnly = false

  var body: some View {
    let label = state.actionLabel ?? attributes.stopLabel
    let symbol = display.showsProgress ? "stop.fill" : "xmark"
    Button(intent: StopAiAnalysisIntent(executionId: attributes.executionId,
      captureId: attributes.captureId, userId: attributes.userId)) {
      Group {
        if iconOnly {
          Image(systemName: symbol)
        } else {
          Label {
            Text(verbatim: label)
          } icon: {
            Image(systemName: symbol)
          }
          .fixedSize()
        }
      }
      .font(.callout.weight(.medium))
      // The bordered capsule adds its own insets; 30 + those insets gives the
      // 44-point minimum target without an oversized row.
      .frame(minWidth: 30, minHeight: 30)
      .contentShape(Rectangle())
    }
    .buttonStyle(.bordered)
    .buttonBorderShape(.capsule)
    .tint(display.tint)
    .accessibilityLabel(Text(verbatim: label))
  }
}

@available(iOS 17.0, *)
private struct AiAnalysisActivityIcon: View {
  let display: AiAnalysisDisplay
  var compact = false
  @ScaledMetric(relativeTo: .headline) private var iconSize = 24

  var body: some View {
    Group {
      if display.showsProgress {
        AiAnalysisProgressRing(progress: display.progress, tint: display.tint,
          lineWidth: compact ? 2.5 : 3)
      } else {
        // Filled circular symbols continue the ring's geometry when the
        // state resolves, so the change reads as completion, not replacement.
        Image(systemName: display.symbol)
          .resizable()
          .scaledToFit()
          .foregroundStyle(display.tint)
      }
    }
    // Icon-only compact/minimal views also fit Apple's 28-point limited-width
    // presentation. These bounds size artwork, not text or the activity itself.
    .frame(width: compact ? 20 : min(iconSize, 32), height: compact ? 20 : min(iconSize, 32))
  }
}

/// Theme-tinted determinate ring. Live Activities cannot spin an indeterminate
/// indicator continuously, so the arc advances with each real analysis stage
/// using a short animation that stays within WidgetKit's two-second limit.
@available(iOS 17.0, *)
private struct AiAnalysisProgressRing: View {
  let progress: Double
  let tint: Color
  var lineWidth: CGFloat = 3
  @Environment(\.isLuminanceReduced) private var isLuminanceReduced

  var body: some View {
    ZStack {
      Circle()
        .stroke(tint.opacity(isLuminanceReduced ? 0.35 : 0.22), lineWidth: lineWidth)
      Circle()
        .trim(from: 0, to: progress)
        .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
        .rotationEffect(.degrees(-90))
        .animation(.easeInOut(duration: 0.6), value: progress)
    }
    // Keep the stroke inside the frame so compact artwork never clips.
    .padding(lineWidth / 2)
    .accessibilityHidden(true)
  }
}

#if DEBUG
@available(iOS 17.0, *)
private enum AiAnalysisActivityPreview {
  static let attributes = AiAnalysisActivityAttributes(
    executionId: "preview", captureId: "preview", userId: "preview",
    title: "Moneko", stopLabel: "Stop")
  static let loading = AiAnalysisActivityAttributes.ContentState(
    message: "Reading your input…", phase: .loading, title: "Analyzing", actionLabel: "Stop",
    staleTitle: "Moneko", staleMessage: "Analysis paused. Open Moneko to continue.",
    progress: aiAnalysisStageProgress("analyzing"))
  static let preparing = AiAnalysisActivityAttributes.ContentState(
    message: "Preparing transactions…", phase: .loading, title: "Analyzing", actionLabel: "Stop",
    progress: aiAnalysisStageProgress("saving"))
  static let success = AiAnalysisActivityAttributes.ContentState(
    message: "Analysis complete. Transactions queued to sync.", phase: .success, title: "Analysis complete")
  static let error = AiAnalysisActivityAttributes.ContentState(
    message: "Analysis could not finish. Open Moneko to retry or cancel.", phase: .error,
    title: "Analysis failed", actionLabel: "Cancel")
  static let confirmation = AiAnalysisActivityAttributes.ContentState(
    message: "Additional confirmation required. Open Moneko to continue.", phase: .confirmation,
    title: "Confirmation required", actionLabel: "Cancel")
}

#Preview("Expanded states", as: .dynamicIsland(.expanded), using: AiAnalysisActivityPreview.attributes) {
  AiAnalysisLiveActivity()
} contentStates: {
  AiAnalysisActivityPreview.loading
  AiAnalysisActivityPreview.preparing
  AiAnalysisActivityPreview.success
  AiAnalysisActivityPreview.error
  AiAnalysisActivityPreview.confirmation
}

#Preview("Expanded · long German", as: .dynamicIsland(.expanded),
  using: AiAnalysisActivityAttributes(executionId: "preview", captureId: "preview", userId: "preview",
    title: "Moneko", stopLabel: "Stoppen")) {
  AiAnalysisLiveActivity()
} contentStates: {
  AiAnalysisActivityAttributes.ContentState(
    message: "Deine Eingabe wird gelesen und die Transaktionen werden vorbereitet…",
    phase: .loading, title: "Analyse läuft", actionLabel: "Stoppen", progress: 0.35)
  AiAnalysisActivityAttributes.ContentState(
    message: "Zusätzliche Bestätigung erforderlich. Öffne Moneko, um die Analyse fortzusetzen.",
    phase: .confirmation, title: "Zusätzliche Bestätigung erforderlich", actionLabel: "Abbrechen")
}

#Preview("Compact states", as: .dynamicIsland(.compact), using: AiAnalysisActivityPreview.attributes) {
  AiAnalysisLiveActivity()
} contentStates: {
  AiAnalysisActivityPreview.loading
  AiAnalysisActivityPreview.success
  AiAnalysisActivityPreview.error
  AiAnalysisActivityPreview.confirmation
}

#Preview("Minimal states", as: .dynamicIsland(.minimal), using: AiAnalysisActivityPreview.attributes) {
  AiAnalysisLiveActivity()
} contentStates: {
  AiAnalysisActivityPreview.loading
  AiAnalysisActivityPreview.success
  AiAnalysisActivityPreview.error
  AiAnalysisActivityPreview.confirmation
}

#Preview("Lock Screen states", as: .content, using: AiAnalysisActivityPreview.attributes) {
  AiAnalysisLiveActivity()
} contentStates: {
  AiAnalysisActivityPreview.loading
  AiAnalysisActivityPreview.success
  AiAnalysisActivityPreview.error
  AiAnalysisActivityPreview.confirmation
}

#Preview("Stale loading") {
  AiAnalysisActivityContent(attributes: AiAnalysisActivityPreview.attributes,
    state: AiAnalysisActivityPreview.loading, isStale: true)
    .padding(14)
    .frame(width: 360)
}

#Preview("Long German · narrow") {
  AiAnalysisActivityContent(
    attributes: AiAnalysisActivityAttributes(executionId: "preview", captureId: "preview", userId: "preview",
      title: "Moneko", stopLabel: "Analyse abbrechen"),
    state: AiAnalysisActivityAttributes.ContentState(
      message: "Zusätzliche Bestätigung erforderlich. Öffne Moneko, um die Analyse fortzusetzen.",
      phase: .confirmation, title: "Zusätzliche Bestätigung erforderlich", actionLabel: "Abbrechen"))
    .padding(14)
    .frame(width: 320)
    .environment(\.locale, Locale(identifier: "de"))
}

#Preview("RTL · larger text") {
  AiAnalysisActivityContent(
    attributes: AiAnalysisActivityAttributes(executionId: "preview", captureId: "preview", userId: "preview",
      title: "Moneko", stopLabel: "روکیں"),
    state: AiAnalysisActivityAttributes.ContentState(
      message: "مزید تصدیق درکار ہے۔ جاری رکھنے کے لیے Moneko کھولیں۔",
      phase: .confirmation, title: "مزید تصدیق درکار ہے", actionLabel: "منسوخ کریں"))
    .padding(14)
    .frame(width: 360)
    .environment(\.layoutDirection, .rightToLeft)
    .environment(\.locale, Locale(identifier: "ur"))
    .dynamicTypeSize(.accessibility1)
}
#endif
