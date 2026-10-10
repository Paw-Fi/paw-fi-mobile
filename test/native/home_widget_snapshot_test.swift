import Foundation

@main
struct HomeWidgetSnapshotTests {
    static func main() throws {
        let raw = ##"{"version":1,"userId":"user-1","currency":"EUR","totalSpent":"€180.00","remainingBudget":"€905.00","progress":0.166,"pockets":[{"name":"旅行","spent":200,"budget":125,"currency":"USD","color":"#7458FF"}],"topCategories":[{"name":"食料品","spent":180,"budget":0,"currency":"EUR","color":"#7458FF"}]}"##
        var store: [String: Any] = ["widget_user_id": "user-1", "widget_snapshot_personal_EUR": raw]
        func read(_ categories: Bool = false) -> HomeWidgetSnapshotReader.Values {
            HomeWidgetSnapshotReader.read(value: { store[$0] }, scopeId: "personal", currency: "EUR",
                                          categories: categories, allowLegacyGlobal: true)
        }
        assert(read().totalSpent == "€180.00")
        assert(read().pockets.first?.currency == "USD")
        assert(read().pockets.first?.spent == 200)
        assert(read().pockets.first?.budget == 125)
        assert(read(true).pockets.first?.currency == "EUR")
        assert(read(true).pockets.first?.spent == 180)
        let usd = PocketData(name: "旅行", spent: 200, budget: 125, color: "#7458FF", currency: "USD", icon: nil)
        let eur = PocketData(name: "旅行", spent: 10, budget: 100, color: "#7458FF", currency: "EUR", icon: nil)
        assert(usd.id != eur.id)
        store["widget_user_id"] = "user-2"
        store["total_spent_personal_EUR"] = "€999.00"
        assert(read().totalSpent == "—")
        store["widget_user_id"] = ""
        assert(read().totalSpent == "—")
        store["widget_user_id"] = "user-1"
        for corrupted in ["{", "{}", raw.replacingOccurrences(of: "EUR", with: "GBP")] {
            store["widget_snapshot_personal_EUR"] = corrupted
            assert(read().totalSpent == "—")
        }
        store.removeValue(forKey: "widget_user_id")
        store["remaining_budget_personal_EUR"] = "€1.00"
        assert(read().totalSpent == "€999.00")
        store = [:]
        assert(read().totalSpent == "—")
        print("iOS widget reader: ownership, corruption, upgrade, aggregates and native rows passed")
    }
}
