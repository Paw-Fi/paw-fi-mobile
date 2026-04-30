import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Theme

struct Theme {
    static let lightBackground = Color(hex: "#F9FAFB")
    static let darkBackground = Color(hex: "#0A0E1A")
    
    static let lightForeground = Color(hex: "#1F2937")
    static let darkForeground = Color(hex: "#F1F5F9")
    
    static let lightPrimary = Color(hex: "#7458FF")
    static let darkPrimary = Color(hex: "#8B70FF")
    
    static let lightMuted = Color(hex: "#6B7280")
    static let darkMuted = Color(hex: "#9CA3AF")
    
    static let lightCard = Color(hex: "#FFFFFF")
    static let darkCard = Color(hex: "#1C1C1E")
}

extension View {
    @ViewBuilder
    func widgetBackground(_ colorScheme: ColorScheme) -> some View {
        if #available(iOS 17.0, *) {
            self.containerBackground(for: .widget) {
                Color.clear
            }
        } else {
            self.background(Color.clear)
        }
    }
}

// MARK: - Data Models

struct PocketData: Codable, Identifiable {
    var id: String { name }
    let name: String
    let spent: Double
    let budget: Double
    let color: String
    let currency: String?
    let icon: String?
}

struct MonekoEntry: TimelineEntry {
    let date: Date
    let totalSpent: String
    let remainingBudget: String
    let progress: Double
    let pockets: [PocketData]
    let currencyCode: String
    let configuration: ConfigurationAppIntent?
}

// MARK: - Providers

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> MonekoEntry {
        MonekoEntry.pocketPlaceholder
    }

    func getSnapshot(in context: Context, completion: @escaping (MonekoEntry) -> ()) {
        completion(loadData())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MonekoEntry>) -> ()) {
        completion(Timeline(entries: [loadData()], policy: .never))
    }
    
    private func loadData() -> MonekoEntry {
        return DataLoader.load(configuration: nil)
    }
}

@available(iOS 17.0, *)
struct AppIntentProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> MonekoEntry {
        MonekoEntry.pocketPlaceholder
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> MonekoEntry {
        if context.isPreview {
            return MonekoEntry.pocketPlaceholder
        }
        return DataLoader.load(configuration: configuration)
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<MonekoEntry> {
        if context.isPreview {
            return Timeline(entries: [MonekoEntry.pocketPlaceholder], policy: .never)
        }
        let entry = DataLoader.load(configuration: configuration)
        return Timeline(entries: [entry], policy: .never)
    }
}

@available(iOS 17.0, *)
struct TopCategoriesAppIntentProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> MonekoEntry {
        MonekoEntry.categoryPlaceholder
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> MonekoEntry {
        if context.isPreview {
            return MonekoEntry.categoryPlaceholder
        }
        return DataLoader.load(
            configuration: configuration,
            pocketsKeyBase: "top_categories"
        )
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<MonekoEntry> {
        if context.isPreview {
            return Timeline(entries: [MonekoEntry.categoryPlaceholder], policy: .never)
        }
        let entry = DataLoader.load(
            configuration: configuration,
            pocketsKeyBase: "top_categories"
        )
        return Timeline(entries: [entry], policy: .never)
    }
}

// MARK: - Data Loader

struct DataLoader {
    static func load(configuration: ConfigurationAppIntent?, pocketsKeyBase: String = "pockets_data") -> MonekoEntry {
        let userDefaults = UserDefaults(suiteName: "group.moneko.mobile")
        
        let scopeId = configuration?.household?.id
        let rawCurrency = userDefaults?.string(forKey: "selected_widget_currency") ?? "USD"
        let trimmedCurrency = rawCurrency.trimmingCharacters(in: .whitespacesAndNewlines)
        let currency = trimmedCurrency.isEmpty ? "USD" : trimmedCurrency.uppercased()
        
        var suffix = ""
        if let s = scopeId {
            suffix = "_\(s)_\(currency)"
        }
        
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
            currencyCode: currency,
            configuration: configuration
        )
    }
}

extension MonekoEntry {
    var isHouseholdScope: Bool {
        guard let scopeId = configuration?.household?.id else {
            return false
        }
        return scopeId != "personal"
    }

    var spentTitle: String {
        isHouseholdScope ? "Spent by Household" : "Spent"
    }

    static var categoryPlaceholder: MonekoEntry {
        MonekoEntry(
            date: Date(),
            totalSpent: "$1,250",
            remainingBudget: "$750",
            progress: 0.65,
            pockets: [
                PocketData(name: "Groceries", spent: 450, budget: 600, color: "#7458FF", currency: "USD", icon: "shopping_bag"),
                PocketData(name: "Transport", spent: 120, budget: 200, color: "#16CDA2", currency: "USD", icon: "directions_car"),
                PocketData(name: "Dining", spent: 300, budget: 400, color: "#FFC219", currency: "USD", icon: "restaurant")
            ],
            currencyCode: "USD",
            configuration: ConfigurationAppIntent(household: HouseholdEntity(id: "personal", name: "Personal"))
        )
    }
    
    static var pocketPlaceholder: MonekoEntry {
        MonekoEntry(
            date: Date(),
            totalSpent: "$850",
            remainingBudget: "$1,150",
            progress: 0.42,
            pockets: [
                PocketData(name: "Pocket 1", spent: 250, budget: 500, color: "#7458FF", currency: "USD", icon: "savings"),
                PocketData(name: "Pocket 2", spent: 100, budget: 300, color: "#16CDA2", currency: "USD", icon: "savings"),
                PocketData(name: "Pocket 3", spent: 50, budget: 200, color: "#FFC219", currency: "USD", icon: "savings"),
                PocketData(name: "Pocket 4", spent: 300, budget: 400, color: "#F05252", currency: "USD", icon: "savings"),
                PocketData(name: "Pocket 5", spent: 150, budget: 600, color: "#3F83F8", currency: "USD", icon: "savings")
            ],
            currencyCode: "USD",
            configuration: ConfigurationAppIntent(household: HouseholdEntity(id: "personal", name: "Personal"))
        )
    }
}

// MARK: - App Intents (Configuration)

@available(iOS 17.0, *)
struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Configuration"
    static var description = IntentDescription("Select a space.")

    @Parameter(title: "Space")
    var household: HouseholdEntity?
    
    init() {}
    
    init(household: HouseholdEntity?) {
        self.household = household
    }
}

@available(iOS 16.0, *)
struct HouseholdEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Space"
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

struct MapItem: Codable {
    let id: String
    let name: String
}

// MARK: - Views

struct MonekoWidgetEntryView : View {
    var entry: MonekoEntry
    @Environment(\.widgetFamily) var family
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        if shouldShowSetup {
            SetupWidgetView()
        } else {
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
    
    var shouldShowSetup: Bool {
        if let config = entry.configuration {
            return config.household == nil || config.currency == nil
        }
        return false
    }
}

struct TopCategoriesWidgetEntryView: View {
    var entry: MonekoEntry
    @Environment(\.widgetFamily) var family
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        if shouldShowSetup {
            SetupWidgetView()
        } else {
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
    
    var shouldShowSetup: Bool {
        if let config = entry.configuration {
            return config.household == nil || config.currency == nil
        }
        return false
    }
}

struct SetupWidgetView: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 32))
                .foregroundColor(colorScheme == .dark ? Theme.darkMuted : Theme.lightMuted)
            
            Text("Long press to edit")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(colorScheme == .dark ? Theme.darkMuted : Theme.lightMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetBackground(colorScheme)
    }
}

struct SmallWidgetView: View {
    let entry: MonekoEntry
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chart.pie.fill")
                    .foregroundColor(colorScheme == .dark ? Theme.darkPrimary : Theme.lightPrimary)
                Spacer()
                Link(destination: URL(string: "moneko://text")!) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 24, height: 24)
                        .background(colorScheme == .dark ? Theme.darkPrimary : Theme.lightPrimary)
                        .clipShape(Circle())
                }
            }
            
            Spacer()
            
            Text(entry.spentTitle)
                .font(.caption)
                .foregroundColor(colorScheme == .dark ? Theme.darkMuted : Theme.lightMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            Text(entry.totalSpent)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(colorScheme == .dark ? Theme.darkForeground : Theme.lightForeground)
                .minimumScaleFactor(0.8)
            
            ProgressBar(value: entry.progress, color: colorScheme == .dark ? Theme.darkPrimary : Theme.lightPrimary)
                .frame(height: 6)
        }
        .padding()
        .widgetBackground(colorScheme)
    }
}

struct MediumWidgetView: View {
    let entry: MonekoEntry
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 16) {
            // Left: Summary
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.isHouseholdScope ? entry.spentTitle : "This Month")
                    .font(.caption)
                    .foregroundColor(colorScheme == .dark ? Theme.darkMuted : Theme.lightMuted)
                    .textCase(.uppercase)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                
                Text(entry.totalSpent)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(colorScheme == .dark ? Theme.darkForeground : Theme.lightForeground)
                
                Text("Left: \(entry.remainingBudget)")
                    .font(.subheadline)
                    .foregroundColor(colorScheme == .dark ? Theme.darkMuted : Theme.lightMuted)
                
                Spacer()
                
                ProgressBar(value: entry.progress, color: colorScheme == .dark ? Theme.darkPrimary : Theme.lightPrimary)
                    .frame(height: 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Right: Actions
            VStack(spacing: 12) {
                Link(destination: URL(string: "moneko://text")!) {
                    HStack {
                        Image(systemName: "square.and.pencil")
                        Text("Add")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(colorScheme == .dark ? Theme.darkPrimary : Theme.lightPrimary)
                    .cornerRadius(12)
                }
                
                Link(destination: URL(string: "moneko://camera")!) {
                    HStack {
                        Image(systemName: "camera")
                        Text("Scan")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? Theme.darkPrimary : Theme.lightPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background((colorScheme == .dark ? Theme.darkPrimary : Theme.lightPrimary).opacity(0.15))
                    .cornerRadius(12)
                }
            }
            .frame(width: 100)
        }
        .padding()
        .widgetBackground(colorScheme)
    }
}

struct LargeWidgetView: View {
    let entry: MonekoEntry
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.spentTitle)
                        .font(.caption2)
                        .foregroundColor(colorScheme == .dark ? Theme.darkMuted : Theme.lightMuted)
                        .textCase(.uppercase)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(entry.totalSpent)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(colorScheme == .dark ? Theme.darkForeground : Theme.lightForeground)
                }
                Spacer()
                Link(destination: URL(string: "moneko://text")!) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(colorScheme == .dark ? Theme.darkPrimary : Theme.lightPrimary)
                }
            }
            
            ProgressBar(value: entry.progress, color: colorScheme == .dark ? Theme.darkPrimary : Theme.lightPrimary)
                .frame(height: 6)

            Divider()
                .overlay(colorScheme == .dark ? Theme.darkMuted.opacity(0.5) : Theme.lightMuted.opacity(0.2))

            // Budget envelopes list – always show all pockets
            VStack(spacing: 12) {
                ForEach(entry.pockets.prefix(5)) { pocket in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            IconCircleView(
                                iconName: pocket.icon,
                                fallbackColorHex: pocket.color,
                                size: 16
                            )

                            Text(pocket.name)
                                .font(.system(size: 13, weight: .medium))
                                .lineLimit(1)
                                .foregroundColor(colorScheme == .dark ? Theme.darkForeground : Theme.lightForeground)

                            Spacer()

                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text(formatCurrency(pocket.spent, currencyCode: pocket.currency))
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(colorScheme == .dark ? Theme.darkForeground : Theme.lightForeground)
                                
                                Text("/")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundColor(colorScheme == .dark ? Theme.darkMuted : Theme.lightMuted)
                                    .padding(.horizontal, 1)

                                Text(formatCurrency(pocket.budget, currencyCode: pocket.currency))
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundColor(colorScheme == .dark ? Theme.darkMuted : Theme.lightMuted)
                            }
                        }

                        ProgressBar(
                            value: pocket.budget > 0 ? min(pocket.spent / pocket.budget, 1.0) : 0.0,
                            color: Color(hex: pocket.color)
                        )
                        .frame(height: 5)
                    }
                }
                if entry.pockets.isEmpty {
                    Text("No pockets yet")
                        .font(.caption)
                        .foregroundColor(colorScheme == .dark ? Theme.darkMuted : Theme.lightMuted)
                }
            }

            Spacer()
        }
        .padding()
        .widgetBackground(colorScheme)
    }
}

struct TopCategoriesLargeWidgetView: View {
    let entry: MonekoEntry
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Top Spending")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(colorScheme == .dark ? Theme.darkMuted : Theme.lightMuted)
                        .textCase(.uppercase)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(entry.totalSpent)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(colorScheme == .dark ? Theme.darkForeground : Theme.lightForeground)
                        
                        if let totalBudget = getTotalBudget(from: entry.pockets), totalBudget > 0 {
                            Text("/ \(formatCurrency(totalBudget, currencyCode: entry.currencyCode))")
                                .font(.caption)
                                .foregroundColor(colorScheme == .dark ? Theme.darkMuted : Theme.lightMuted)
                        }
                    }
                }
                Spacer()
                Link(destination: URL(string: "moneko://text")!) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Circle().fill(colorScheme == .dark ? Theme.darkPrimary : Theme.lightPrimary))
                }
            }

            // Chart
            if !entry.pockets.isEmpty {
                 VerticalBarChart(pockets: Array(entry.pockets.prefix(5)), colorScheme: colorScheme)
                    .frame(maxHeight: .infinity)
            } else {
                VStack {
                    Spacer()
                    Text("No expenses yet")
                        .font(.subheadline)
                        .foregroundColor(colorScheme == .dark ? Theme.darkMuted : Theme.lightMuted)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(20)
        .widgetBackground(colorScheme)
    }
    
    func getTotalBudget(from pockets: [PocketData]) -> Double? {
        // This is a rough estimate if we don't have total budget explicitly for the "Top Categories" intent.
        // But usually, we only care about spent vs specific budgets.
        // Let's just return nil to hide it or calculate if appropriate.
        // In the entry, we have 'remainingBudget' which implies a total.
        return nil
    }
}

struct VerticalBarChart: View {
    let pockets: [PocketData]
    let colorScheme: ColorScheme
    
    var maxSpent: Double {
        pockets.map(\.spent).max() ?? 1.0
    }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            ForEach(pockets) { pocket in
                VStack(spacing: 8) {
                    // Amount (Hidden if too small space, but good for large)
                    Text(shortAmount(pocket.spent))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(colorScheme == .dark ? Theme.darkMuted : Theme.lightMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    
                    // Bar
                    GeometryReader { geo in
                        VStack {
                            Spacer()
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(hex: pocket.color))
                                .frame(height: max(10, CGFloat(pocket.spent / maxSpent) * geo.size.height))
                                .overlay(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.white.opacity(0.1),
                                            Color.clear
                                        ]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                    .cornerRadius(6)
                                )
                        }
                    }
                    
                    // Name
                    Text(pocket.name)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(colorScheme == .dark ? Theme.darkForeground : Theme.lightForeground)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(height: 16)
                }
            }
        }
    }
    
    func shortAmount(_ amount: Double) -> String {
        if amount >= 1000 {
            return String(format: "%.1fk", amount / 1000)
        }
        return String(format: "%.0f", amount)
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

struct IconCircleView: View {
    let iconName: String?
    let fallbackColorHex: String
    let size: CGFloat

    var body: some View {
        let systemName: String = {
            if let iconName, let mapped = mapIconIdentifierToSymbol(iconName) {
                return mapped
            }
            // Fallback to banknote
            return "banknote.fill"
        }()

        ZStack {
            Circle()
                .fill(Color(hex: fallbackColorHex).opacity(0.15))
                .frame(width: size + 8, height: size + 8)
            Image(systemName: systemName)
                .font(.system(size: size * 0.7, weight: .semibold))
                .foregroundColor(Color(hex: fallbackColorHex))
        }
    }
}

fileprivate func mapIconIdentifierToSymbol(_ identifier: String) -> String? {
    let key = identifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

    switch key {
    case "shopping_bag":
        return "bag.fill"
    case "restaurant":
        return "fork.knife"
    case "directions_car":
        return "car.fill"
    case "home":
        return "house.fill"
    case "flight":
        return "airplane"
    case "medical_services":
        return "cross.case.fill"
    case "school":
        return "book.fill"
    case "pets":
        return "pawprint.fill"
    case "sports_esports":
        return "gamecontroller.fill"
    case "fitness_center":
        return "figure.strengthtraining.traditional"
    case "local_cafe":
        return "cup.and.saucer.fill"
    case "local_bar":
        return "wineglass.fill"
    case "movie":
        return "film.fill"
    case "music_note":
        return "music.note"
    case "savings", "savings_outlined":
        return "banknote.fill"
    case "account_balance":
        return "building.columns.fill"
    case "groceries":
        return "cart.fill"
    case "food & drinks", "restaurants", "takeout & delivery":
        return "fork.knife"
    case "coffee & tea":
        return "cup.and.saucer.fill"
    case "snacks":
        return "takeoutbag.and.cup.and.straw.fill"
    case "public transport":
        return "tram.fill"
    case "taxi & ride apps":
        return "car.fill"
    case "fuel / gas":
        return "fuelpump.fill"
    case "travel", "flights":
        return "airplane"
    case "hotels":
        return "bed.double.fill"
    case "medical care", "pharmacy":
        return "cross.case.fill"
    case "fitness & gym", "sports & exercise":
        return "figure.run"
    case "movies & shows":
        return "film.fill"
    case "music & streaming":
        return "music.note.list"
    case "games & apps":
        return "gamecontroller.fill"
    case "gifts", "bonus":
        return "gift.fill"
    case "income", "salary":
        return "banknote.fill"
    case "investments":
        return "chart.line.uptrend.xyaxis"
    default:
        return nil
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
