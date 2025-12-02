import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let entries = [SimpleEntry(date: Date())]
        let timeline = Timeline(entries: entries, policy: .never)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
}

struct MonekoWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        HStack(spacing: 0) {
            Link(destination: URL(string: "moneko://text")!) {
                VStack {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                    Text("Text")
                        .font(.caption)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(red: 0.17, green: 0.17, blue: 0.18)) // #2C2C2E
            }
            
            Divider()
                .background(Color.gray)
            
            Link(destination: URL(string: "moneko://camera")!) {
                VStack {
                    Image(systemName: "camera")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                    Text("Camera")
                        .font(.caption)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(red: 0.17, green: 0.17, blue: 0.18))
            }
        }
        .background(Color(red: 0.17, green: 0.17, blue: 0.18))
    }
}

struct MonekoWidget: Widget {
    let kind: String = "MonekoWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            MonekoWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Quick Log")
        .description("Log expenses instantly.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
