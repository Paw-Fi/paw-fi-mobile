import Foundation

struct PocketData: Codable, Identifiable {
    var pocketId: String? = nil
    var id: String { pocketId ?? "\(currency ?? ""):\(name)" }
    let name: String
    let spent: Double
    let budget: Double
    let color: String
    let currency: String?
    let icon: String?

    enum CodingKeys: String, CodingKey {
        case pocketId = "id"
        case name, spent, budget, color, currency, icon
    }
}

struct StoredHomeWidgetSnapshot: Decodable {
    let version: Int
    let userId: String
    let currency: String
    let totalSpent: String
    let remainingBudget: String
    let progress: Double
    let pockets: [PocketData]
    let topCategories: [PocketData]?
}

struct HomeWidgetSnapshotReader {
    struct Values {
        let totalSpent: String
        let remainingBudget: String
        let progress: Double
        let pockets: [PocketData]
        static let unavailable = Values(totalSpent: "—", remainingBudget: "—", progress: 0, pockets: [])
    }

    static func read(value: (String) -> Any?, scopeId: String, currency: String,
                     categories: Bool, allowLegacyGlobal: Bool) -> Values {
        let suffix = "_\(scopeId)_\(currency)"
        if let owner = value("widget_user_id") as? String {
            guard !owner.isEmpty,
                  let raw = value("widget_snapshot\(suffix)") as? String,
                  let data = raw.data(using: .utf8),
                  let snapshot = try? JSONDecoder().decode(StoredHomeWidgetSnapshot.self, from: data),
                  snapshot.version == 1, snapshot.userId == owner, snapshot.currency == currency,
                  snapshot.progress.isFinite else { return .unavailable }
            let pockets = (categories ? snapshot.topCategories : snapshot.pockets) ?? []
            guard pockets.allSatisfy({ $0.spent.isFinite && $0.budget.isFinite }) else { return .unavailable }
            return Values(totalSpent: snapshot.totalSpent, remainingBudget: snapshot.remainingBudget,
                          progress: min(1, max(0, snapshot.progress)), pockets: pockets)
        }
        // Upgrade compatibility ends as soon as Flutter establishes an owner.
        let legacyCurrency = (value("legacy_widget_currency") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let legacy = allowLegacyGlobal && legacyCurrency == currency
        guard let spent = value("total_spent\(suffix)") as? String ?? (legacy ? value("total_spent") as? String : nil),
              let remaining = value("remaining_budget\(suffix)") as? String ?? (legacy ? value("remaining_budget") as? String : nil)
        else { return .unavailable }
        let progress = (value("budget_progress\(suffix)") as? NSNumber)?.doubleValue
            ?? (legacy ? (value("budget_progress") as? NSNumber)?.doubleValue : nil) ?? 0
        let base = categories ? "top_categories" : "pockets_data"
        let raw = value("\(base)\(suffix)") as? String ?? (legacy ? value(base) as? String : nil)
        let pockets = raw?.data(using: .utf8).flatMap { try? JSONDecoder().decode([PocketData].self, from: $0) } ?? []
        return Values(totalSpent: spent, remainingBudget: remaining,
                      progress: progress.isFinite ? min(1, max(0, progress)) : 0, pockets: pockets)
    }
}
