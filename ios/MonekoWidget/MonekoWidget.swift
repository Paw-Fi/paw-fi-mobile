import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Data Models

struct PocketData: Codable, Identifiable {
    var id: String { name }
    let name: String
    let spent: Double
    let budget: Double
    let color: String
    let currency: String?
}

struct MonekoEntry: TimelineEntry {
    let date: Date
    let totalSpent: String
    let remainingBudget: String
    let progress: Double
    let pockets: [PocketData]
    let configuration: ConfigurationAppIntent? // Optional for static widget
}

// MARK: - Providers

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> MonekoEntry {
        MonekoEntry.placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (MonekoEntry) -> ()) {
        completion(loadData())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MonekoEntry>) -> ()) {
        completion(Timeline(entries: [loadData()], policy: .never))
    }
    
    private func loadData() -> MonekoEntry {
        // Load default/legacy data (no scope suffix)
        return DataLoader.load(scopeId: nil, currency: nil)
    }
}

@available(iOS 17.0, *)
struct AppIntentProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> MonekoEntry {
        MonekoEntry.placeholder
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> MonekoEntry {
        return DataLoader.load(scopeId: configuration.household?.id, currency: configuration.currency?.id)
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<MonekoEntry> {
        let entry = DataLoader.load(scopeId: configuration.household?.id, currency: configuration.currency?.id)
        return Timeline(entries: [entry], policy: .never)
    }
}

@available(iOS 17.0, *)
struct TopCategoriesAppIntentProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> MonekoEntry {
        MonekoEntry.placeholder
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> MonekoEntry {
        return DataLoader.load(
            scopeId: configuration.household?.id,
            currency: configuration.currency?.id,
            pocketsKeyBase: "top_categories"
        )
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<MonekoEntry> {
        let entry = DataLoader.load(
            scopeId: configuration.household?.id,
            currency: configuration.currency?.id,
            pocketsKeyBase: "top_categories"
        )
        return Timeline(entries: [entry], policy: .never)
    }
}

// MARK: - Data Loader

struct DataLoader {
    static func load(scopeId: String?, currency: String?, pocketsKeyBase: String = "pockets_data") -> MonekoEntry {
        let userDefaults = UserDefaults(suiteName: "group.moneko.mobile")
        
        // Construct keys based on configuration
        // If scopeId is provided, use it. If not, fallback to default keys (no suffix)
        // Note: WidgetService saves with suffix: {scopeId}_{currency}
        // scopeId 'personal' is used for personal scope.
        
        var suffix = ""
        if let s = scopeId, let c = currency {
            suffix = "_\(s)_\(c)"
        } else if let s = scopeId {
             // Try to find default currency? Or just fail?
             // For now, if currency is missing, we might not find data.
             // But let's assume if scope is 'personal', we might have legacy data without suffix?
             // No, WidgetService saves legacy data to 'total_spent' etc. AND 'total_spent_personal_USD'.
             // So if scopeId is nil, we read legacy keys.
        }
        
        // If we have a specific configuration, use the suffix.
        // If scopeId is "personal" and currency is "USD", suffix is "_personal_USD".
        
        let totalSpentKey = "total_spent\(suffix)"
        let remainingKey = "remaining_budget\(suffix)"
        let progressKey = "budget_progress\(suffix)"
        let pocketsKey = "\(pocketsKeyBase)\(suffix)"
        
        let totalSpent = userDefaults?.string(forKey: totalSpentKey) ?? "$0"
        let remainingBudget = userDefaults?.string(forKey: remainingKey) ?? "$0"
        let progress = userDefaults?.double(forKey: progressKey) ?? 0.0
        
        var pockets: [PocketData] = []
        if let pocketsJson = userDefaults?.string(forKey: pocketsKey),
           let data = pocketsJson.data(using: .utf8) {
            do {
                pockets = try JSONDecoder().decode([PocketData].self, from: data)
            } catch {
                print("Error decoding pockets: \(error)")
            }
        }
        
        return MonekoEntry(
            date: Date(),
            totalSpent: totalSpent,
            remainingBudget: remainingBudget,
            progress: progress,
            pockets: pockets,
            configuration: nil
        )
    }
}

extension MonekoEntry {
    static var placeholder: MonekoEntry {
        MonekoEntry(
            date: Date(),
            totalSpent: "$1,250",
            remainingBudget: "$750",
            progress: 0.65,
            pockets: [
                PocketData(name: "Groceries", spent: 450, budget: 600, color: "#7458FF", currency: "USD"),
                PocketData(name: "Transport", spent: 120, budget: 200, color: "#16CDA2", currency: "USD"),
                PocketData(name: "Dining", spent: 300, budget: 400, color: "#FFC219", currency: "USD")
            ],
            configuration: nil
        )
    }
}

// MARK: - App Intents (Configuration)

@available(iOS 17.0, *)
struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Configuration"
    static var description = IntentDescription("Select household and currency.")

    @Parameter(title: "Household")
    var household: HouseholdEntity?

    @Parameter(title: "Currency")
    var currency: CurrencyEntity?
    
    init() {}
    
    init(household: HouseholdEntity?, currency: CurrencyEntity?) {
        self.household = household
        self.currency = currency
    }
}

@available(iOS 16.0, *)
struct HouseholdEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Household"
    static var defaultQuery = HouseholdQuery()
    
    var id: String
    var name: String
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

@available(iOS 16.0, *)
struct HouseholdQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [HouseholdEntity] {
        return allHouseholds().filter { identifiers.contains($0.id) }
    }
    
    func suggestedEntities() async throws -> [HouseholdEntity] {
        return allHouseholds()
    }
    
    func allHouseholds() -> [HouseholdEntity] {
        let userDefaults = UserDefaults(suiteName: "group.moneko.mobile")
        guard let json = userDefaults?.string(forKey: "config_households"),
              let data = json.data(using: .utf8),
              let list = try? JSONDecoder().decode([MapItem].self, from: data) else {
            return [HouseholdEntity(id: "personal", name: "Personal")]
        }
        return list.map { HouseholdEntity(id: $0.id, name: $0.name) }
    }
}

@available(iOS 16.0, *)
struct CurrencyEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Currency"
    static var defaultQuery = CurrencyQuery()
    
    var id: String // Currency Code
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(id)")
    }
}

@available(iOS 16.0, *)
struct CurrencyQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [CurrencyEntity] {
        return allCurrencies().filter { identifiers.contains($0.id) }
    }
    
    func suggestedEntities() async throws -> [CurrencyEntity] {
        return allCurrencies()
    }
    
    func allCurrencies() -> [CurrencyEntity] {
        let userDefaults = UserDefaults(suiteName: "group.moneko.mobile")
        guard let json = userDefaults?.string(forKey: "config_currencies"),
              let data = json.data(using: .utf8),
              let list = try? JSONDecoder().decode([String].self, from: data) else {
            return [CurrencyEntity(id: "USD")]
        }
        return list.map { CurrencyEntity(id: $0) }
    }
}

struct MapItem: Codable {
    let id: String
    let name: String
}

// MARK: - Views

struct MonekoWidgetEntryView : View {
    var entry: MonekoEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        case .accessoryCircular:
            LockScreenCircularView()
        case .accessoryRectangular:
            LockScreenRectangularView()
        case .accessoryInline:
            Text("Moneko")
        @unknown default:
            SmallWidgetView(entry: entry)
        }
    }
}

// Entry view for the \"Top Spending\" widget variant.
struct TopCategoriesWidgetEntryView: View {
    var entry: MonekoEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            TopCategoriesLargeWidgetView(entry: entry)
        case .accessoryCircular:
            LockScreenCircularView()
        case .accessoryRectangular:
            LockScreenRectangularView()
        case .accessoryInline:
            Text("Moneko")
        @unknown default:
            TopCategoriesLargeWidgetView(entry: entry)
        }
    }
}

// ... (Keep existing View Components: SmallWidgetView, MediumWidgetView, LargeWidgetView, etc.)
// I will re-paste them here to ensure the file is complete and correct.

struct SmallWidgetView: View {
    let entry: MonekoEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chart.pie.fill")
                    .foregroundColor(Color(hex: "#7458FF"))
                Spacer()
                Link(destination: URL(string: "moneko://pockets")!) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 24, height: 24)
                        .background(Color(hex: "#7458FF"))
                        .clipShape(Circle())
                }
            }
            
            Spacer()
            
            Text("Spent")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(entry.totalSpent)
                .font(.system(size: 20, weight: .bold))
                .minimumScaleFactor(0.8)
            
            ProgressBar(value: entry.progress, color: Color(hex: "#7458FF"))
                .frame(height: 6)
        }
        .padding()
        .background(Color("WidgetBackground"))
    }
}

struct MediumWidgetView: View {
    let entry: MonekoEntry
    
    var body: some View {
        HStack(spacing: 16) {
            // Left: Summary
            VStack(alignment: .leading, spacing: 4) {
                Text("This Month")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                Text(entry.totalSpent)
                    .font(.system(size: 26, weight: .bold))
                
                Text("Left: \(entry.remainingBudget)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                ProgressBar(value: entry.progress, color: Color(hex: "#7458FF"))
                    .frame(height: 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Right: Actions
            VStack(spacing: 12) {
                Link(destination: URL(string: "moneko://pockets")!) {
                    HStack {
                        Image(systemName: "square.and.pencil")
                        Text("Add")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color(hex: "#7458FF"))
                    .cornerRadius(12)
                }
                
                Link(destination: URL(string: "moneko://camera")!) {
                    HStack {
                        Image(systemName: "camera")
                        Text("Scan")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "#7458FF"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color(hex: "#7458FF").opacity(0.15))
                    .cornerRadius(12)
                }
            }
            .frame(width: 100)
        }
        .padding()
        .background(Color("WidgetBackground"))
    }
}

struct LargeWidgetView: View {
    let entry: MonekoEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Spent")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    Text(entry.totalSpent)
                        .font(.title2)
                        .fontWeight(.bold)
                }
                Spacer()
                Link(destination: URL(string: "moneko://pockets")!) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(Color(hex: "#7458FF"))
                }
            }
            
            ProgressBar(value: entry.progress, color: Color(hex: "#7458FF"))
                .frame(height: 8)

            Divider()

            // Budget envelopes list – always show all pockets
            VStack(spacing: 12) {
                ForEach(entry.pockets) { pocket in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Circle()
                                .fill(Color(hex: pocket.color))
                                .frame(width: 10, height: 10)

                            Text(pocket.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .lineLimit(1)

                            Spacer()

                            Text(formatCurrency(pocket.spent, currencyCode: pocket.currency))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }

                        ProgressBar(
                            value: pocket.budget > 0 ? min(pocket.spent / pocket.budget, 1.0) : 0.0,
                            color: Color(hex: pocket.color)
                        )
                        .frame(height: 6)

                        HStack {
                            Spacer()
                            Text("of \(formatCurrency(pocket.budget, currencyCode: pocket.currency))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                if entry.pockets.isEmpty {
                    Text("No pockets yet")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding()
        .background(Color("WidgetBackground"))
    }
}

// Original large layout used for the \"Top Spending\" widget variant
struct TopCategoriesLargeWidgetView: View {
    let entry: MonekoEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Spent")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    Text(entry.totalSpent)
                        .font(.title2)
                        .fontWeight(.bold)
                }
                Spacer()
                Link(destination: URL(string: "moneko://pockets")!) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(Color(hex: "#7458FF"))
                }
            }

            ProgressBar(value: entry.progress, color: Color(hex: "#7458FF"))
                .frame(height: 8)

            Divider()

            // Pockets List (top categories)
            VStack(spacing: 12) {
                ForEach(entry.pockets.prefix(4)) { pocket in
                    HStack {
                        Circle()
                            .fill(Color(hex: pocket.color))
                            .frame(width: 8, height: 8)

                        Text(pocket.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)

                        Spacer()

                        Text(formatCurrency(pocket.spent, currencyCode: pocket.currency))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                if entry.pockets.isEmpty {
                    Text("No expenses yet this month")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding()
        .background(Color("WidgetBackground"))
    }
}

struct LockScreenCircularView: View {
    var body: some View {
        Link(destination: URL(string: "moneko://text")!) {
            ZStack {
                Circle()
                    .strokeBorder(Color.white.opacity(0.5), lineWidth: 2)
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .bold))
            }
        }
    }
}

struct LockScreenRectangularView: View {
    var body: some View {
        Link(destination: URL(string: "moneko://camera")!) {
            HStack {
                Image(systemName: "camera")
                Text("Scan Receipt")
                    .fontWeight(.semibold)
            }
            .padding(4)
            .background(ContainerRelativeShape().fill(Color.white.opacity(0.2)))
        }
    }
}

struct ProgressBar: View {
    var value: Double
    var color: Color
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .opacity(0.2)
                    .foregroundColor(color)
                
                Rectangle()
                    .frame(width: min(CGFloat(self.value) * geometry.size.width, geometry.size.width), height: geometry.size.height)
                    .foregroundColor(color)
            }
            .cornerRadius(45.0)
        }
    }
}

fileprivate func formatCurrency(_ amount: Double, currencyCode: String?) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    if let code = currencyCode, !code.isEmpty {
        formatter.currencyCode = code
    }
    return formatter.string(from: NSNumber(value: amount)) ?? String(format: "%.0f", amount)
}

// Helper for Hex Colors
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}



@available(iOS 17.0, *)
struct MonekoWidget: Widget {
    let kind: String = "MonekoWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: AppIntentProvider()) { entry in
            MonekoWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Moneko")
        .description("Track your budget and log expenses.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@available(iOS 17.0, *)
struct MonekoTopCategoriesWidget: Widget {
    let kind: String = "MonekoTopCategoriesWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: ConfigurationAppIntent.self,
            provider: TopCategoriesAppIntentProvider()
        ) { entry in
            TopCategoriesWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Moneko – Top Spending")
        .description("View your top spending categories for the month.")
        .supportedFamilies([.systemLarge])
    }
}
