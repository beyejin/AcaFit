import Foundation

struct ArchiveFolder: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var items: [ArchiveItem]

    init(id: UUID = UUID(), name: String, items: [ArchiveItem]) {
        self.id = id
        self.name = name
        self.items = items
    }

    static let defaults = [
        ArchiveFolder(name: "AI", items: []),
        ArchiveFolder(name: "대학", items: []),
        ArchiveFolder(name: "읽을거리", items: [])
    ]

    static func decode(from json: String) -> [ArchiveFolder] {
        guard let data = json.data(using: .utf8), !data.isEmpty else { return [] }
        return (try? JSONDecoder().decode([ArchiveFolder].self, from: data)) ?? []
    }

    static func encode(_ folders: [ArchiveFolder]) -> String {
        guard let data = try? JSONEncoder().encode(folders) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }
}

struct ArchiveItem: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let url: String
    let note: String
    let createdAt: Date

    init(id: UUID = UUID(), title: String, url: String, note: String, createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.url = url
        self.note = note
        self.createdAt = createdAt
    }
}
