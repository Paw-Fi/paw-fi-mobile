//
//  MonekoWidgetLiveActivity.swift
//  MonekoWidget
//
//  Created by Yifan Lim on 01/12/2025.
//

#if canImport(ActivityKit)
import ActivityKit
import WidgetKit
import SwiftUI

// Live Activities are available on iOS 16.1+. Wrap in availability so the target
// with deployment 15.0 still compiles.
@available(iOS 16.1, *)
struct MonekoWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var emoji: String
    }

    var name: String
}

@available(iOS 16.1, *)
struct MonekoWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MonekoWidgetAttributes.self) { context in
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
        }
    }
}
#endif
