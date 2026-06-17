import Foundation

struct AutomationSystem: Identifiable, Codable, Equatable {
    let id: UUID
    let period: RoutinePeriod
    let name: String
    let launchURL: String
    let note: String

    init(id: UUID = UUID(), period: RoutinePeriod, name: String, launchURL: String, note: String) {
        self.id = id
        self.period = period
        self.name = name
        self.launchURL = launchURL
        self.note = note
    }

    static func decode(from json: String) -> [AutomationSystem] {
        guard let data = json.data(using: .utf8), !data.isEmpty else { return [] }
        return (try? JSONDecoder().decode([AutomationSystem].self, from: data)) ?? []
    }

    static func encode(_ systems: [AutomationSystem]) -> String {
        guard let data = try? JSONEncoder().encode(systems) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }
}
