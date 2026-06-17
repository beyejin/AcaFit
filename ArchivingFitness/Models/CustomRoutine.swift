import Foundation

enum RoutineWeekday: Int, CaseIterable, Codable, Identifiable, Hashable {
    case sunday = 1
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday

    var id: Int { rawValue }

    static let displayOrder: [RoutineWeekday] = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]

    var shortTitle: String {
        switch self {
        case .sunday: "일"
        case .monday: "월"
        case .tuesday: "화"
        case .wednesday: "수"
        case .thursday: "목"
        case .friday: "금"
        case .saturday: "토"
        }
    }
}

struct CustomRoutine: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var videoIDs: [UUID]
    var startMinutes: Int
    var weekdays: [RoutineWeekday]

    init(
        id: UUID = UUID(),
        name: String,
        videoIDs: [UUID] = [],
        startMinutes: Int = 420,
        weekdays: [RoutineWeekday] = [.monday, .tuesday, .wednesday, .thursday, .friday]
    ) {
        self.id = id
        self.name = name
        self.videoIDs = videoIDs
        self.startMinutes = startMinutes
        self.weekdays = weekdays
    }

    var startTimeText: String {
        let hour = startMinutes / 60
        let minute = startMinutes % 60
        return String(format: "%02d:%02d", hour, minute)
    }

    var weekdaysText: String {
        RoutineWeekday.displayOrder
            .filter { weekdays.contains($0) }
            .map(\.shortTitle)
            .joined(separator: ", ")
    }

    var scheduleSummary: String {
        "\(startTimeText) · \(weekdaysText)"
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case videoIDs
        case startMinutes
        case weekdays
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        videoIDs = try container.decode([UUID].self, forKey: .videoIDs)
        startMinutes = try container.decodeIfPresent(Int.self, forKey: .startMinutes) ?? 420
        weekdays = try container.decodeIfPresent([RoutineWeekday].self, forKey: .weekdays)
            ?? [.monday, .tuesday, .wednesday, .thursday, .friday]
    }

    static func decode(from json: String) -> [CustomRoutine] {
        guard let data = json.data(using: .utf8), !data.isEmpty else { return [] }
        return (try? JSONDecoder().decode([CustomRoutine].self, from: data)) ?? []
    }

    static func encode(_ routines: [CustomRoutine]) -> String {
        guard let data = try? JSONEncoder().encode(routines) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }
}

enum RoutineSelection: Equatable, Hashable {
    case automatic
    case custom(UUID)

    var storageString: String {
        switch self {
        case .automatic: "auto"
        case .custom(let id): "custom:\(id.uuidString)"
        }
    }

    static func fromStorage(_ raw: String) -> RoutineSelection {
        if raw == "auto" { return .automatic }
        if raw.hasPrefix("custom:") {
            let idString = String(raw.dropFirst("custom:".count))
            if let id = UUID(uuidString: idString) { return .custom(id) }
        }
        return .automatic
    }
}
