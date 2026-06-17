import Foundation

struct StretchingVideo: Identifiable, Codable, Equatable {
    enum SourceKind: String, Codable, CaseIterable, Identifiable {
        case youtube
        case remoteMP4
        case localFile

        var id: String { rawValue }

        var title: String {
            switch self {
            case .youtube: "YouTube"
            case .remoteMP4: "mp4 링크"
            case .localFile: "가져온 mp4"
            }
        }

        var iconName: String {
            switch self {
            case .youtube: "play.rectangle.fill"
            case .remoteMP4: "play.square.stack.fill"
            case .localFile: "film.fill"
            }
        }
    }

    let id: UUID
    let title: String
    let durationMinutes: Int
    let sourceKind: SourceKind
    let sourceValue: String

    init(id: UUID = UUID(), title: String, durationMinutes: Int, sourceKind: SourceKind, sourceValue: String) {
        self.id = id
        self.title = title
        self.durationMinutes = durationMinutes
        self.sourceKind = sourceKind
        self.sourceValue = sourceValue
    }

    var launchURLString: String {
        switch sourceKind {
        case .youtube, .remoteMP4:
            sourceValue
        case .localFile:
            StretchingVideoFileStore.url(for: sourceValue).absoluteString
        }
    }

    static func decode(from json: String) -> [StretchingVideo] {
        guard let data = json.data(using: .utf8), !data.isEmpty else { return [] }
        return (try? JSONDecoder().decode([StretchingVideo].self, from: data)) ?? []
    }

    static func encode(_ videos: [StretchingVideo]) -> String {
        guard let data = try? JSONEncoder().encode(videos) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }
}

struct StretchingVideoDraft: Identifiable, Equatable {
    let id = UUID()
    var title: String = ""
    var durationMinutes: Int = 5
    var sourceKind: StretchingVideo.SourceKind = .youtube
    var sourceValue: String = ""

    func makeVideo() -> StretchingVideo {
        StretchingVideo(
            title: title.trimmed,
            durationMinutes: durationMinutes,
            sourceKind: sourceKind,
            sourceValue: sourceValue.trimmed
        )
    }
}

struct StretchingPlanRecommendation {
    let targetMinutes: Int
    let videos: [StretchingVideo]

    var totalMinutes: Int {
        videos.reduce(0) { $0 + $1.durationMinutes }
    }

    var remainingMinutes: Int {
        max(targetMinutes - totalMinutes, 0)
    }

    var summary: String {
        guard !videos.isEmpty else { return "등록한 스트레칭 영상이 없어요." }
        let grouped = Dictionary(grouping: videos, by: \.durationMinutes)
            .map { duration, videos in "\(duration)분 \(videos.count)개" }
            .sorted()
            .joined(separator: ", ")
        return "목표 \(targetMinutes)분에 맞춰 \(grouped)를 추천해요."
    }

    static func make(videos: [StretchingVideo], targetMinutes: Int, date: Date = Date()) -> StretchingPlanRecommendation {
        guard !videos.isEmpty else {
            return StretchingPlanRecommendation(targetMinutes: targetMinutes, videos: [])
        }

        let rotated = videos.rotatedForToday(date: date)
        var bestByMinute: [Int: [StretchingVideo]] = [0: []]

        for video in rotated where video.durationMinutes > 0 {
            let current = bestByMinute
            for (minute, selected) in current {
                let newMinute = minute + video.durationMinutes
                guard newMinute <= targetMinutes else { continue }
                if bestByMinute[newMinute] == nil || selected.count + 1 < (bestByMinute[newMinute]?.count ?? Int.max) {
                    bestByMinute[newMinute] = selected + [video]
                }
            }
        }

        if let exact = bestByMinute[targetMinutes] {
            return StretchingPlanRecommendation(targetMinutes: targetMinutes, videos: exact)
        }

        let bestUnder = bestByMinute.keys.max() ?? 0
        if bestUnder > 0, let selected = bestByMinute[bestUnder] {
            return StretchingPlanRecommendation(targetMinutes: targetMinutes, videos: selected)
        }

        let shortest = rotated.min { $0.durationMinutes < $1.durationMinutes }
        return StretchingPlanRecommendation(targetMinutes: targetMinutes, videos: shortest.map { [$0] } ?? [])
    }
}

private extension Array where Element == StretchingVideo {
    func rotatedForToday(date: Date) -> [StretchingVideo] {
        guard !isEmpty else { return [] }
        let day = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        let offset = abs(day) % count
        return Array(self[offset...]) + Array(self[..<offset])
    }
}
