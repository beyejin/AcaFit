import Foundation
import SwiftUI

enum ExerciseCategory: String, CaseIterable, Codable, Identifiable {
    case gym
    case pilates
    case yoga
    case dance
    case swimming
    case stretching
    case recovery
    case cardio
    case homeTraining

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gym: "헬스"
        case .pilates: "필라테스"
        case .yoga: "요가"
        case .dance: "댄스"
        case .swimming: "수영"
        case .stretching: "스트레칭"
        case .recovery: "재활/회복"
        case .cardio: "유산소"
        case .homeTraining: "홈트"
        }
    }

    var iconName: String {
        switch self {
        case .gym: "dumbbell.fill"
        case .pilates: "figure.core.training"
        case .yoga: "figure.mind.and.body"
        case .dance: "figure.dance"
        case .swimming: "figure.pool.swim"
        case .stretching: "figure.flexibility"
        case .recovery: "cross.case.fill"
        case .cardio: "heart.fill"
        case .homeTraining: "house.fill"
        }
    }

    var tint: Color {
        switch self {
        case .gym: .indigo
        case .pilates: .pink
        case .yoga: .green
        case .dance: .purple
        case .swimming: .blue
        case .stretching: .blue
        case .recovery: .teal
        case .cardio: .red
        case .homeTraining: .mint
        }
    }

    var defaultFolders: [String] {
        switch self {
        case .gym: ["상체", "하체", "등", "가슴", "어깨", "팔", "복근", "전신"]
        case .pilates: ["코어", "골반", "자세 교정", "전신", "호흡"]
        case .yoga: ["아침 요가", "저녁 요가", "유연성", "밸런스", "릴리즈"]
        case .dance: ["워밍업", "기본기", "안무", "유산소", "하체 리듬"]
        case .swimming: ["자유형", "배영", "평영", "접영", "턴", "돌핀", "스타트"]
        case .stretching: ["아침 스트레칭", "운동 전", "운동 후", "폼롤러", "목/어깨", "하체"]
        case .recovery: ["허리", "무릎", "발목", "어깨", "고관절", "통증 완화"]
        case .cardio: ["걷기", "러닝", "인터벌", "저강도", "댄스 cardio"]
        case .homeTraining: ["맨몸", "매트", "짧은 루틴", "전신", "초보"]
        }
    }
}

enum ExerciseIntensity: String, CaseIterable, Codable, Identifiable {
    case light
    case normal
    case hard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .light: "가벼움"
        case .normal: "보통"
        case .hard: "힘듦"
        }
    }
}

struct ExerciseVideo: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let youtubeID: String
    var localFileName: String?
    var title: String
    var category: ExerciseCategory
    var folderPath: [String]
    var bodyParts: [String]
    var equipment: [String]
    var goals: [String]
    var durationMinutes: Int
    var intensity: ExerciseIntensity
    var memo: String

    init(
        id: UUID = UUID(),
        youtubeID: String,
        localFileName: String? = nil,
        title: String,
        category: ExerciseCategory,
        folderPath: [String],
        bodyParts: [String],
        equipment: [String],
        goals: [String],
        durationMinutes: Int = 10,
        intensity: ExerciseIntensity = .normal,
        memo: String = ""
    ) {
        self.id = id
        self.youtubeID = youtubeID
        self.localFileName = localFileName
        self.title = title
        self.category = category
        self.folderPath = folderPath
        self.bodyParts = bodyParts
        self.equipment = equipment
        self.goals = goals
        self.durationMinutes = durationMinutes
        self.intensity = intensity
        self.memo = memo
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        youtubeID = try container.decode(String.self, forKey: .youtubeID)
        localFileName = try container.decodeIfPresent(String.self, forKey: .localFileName)
        title = try container.decode(String.self, forKey: .title)
        category = try container.decode(ExerciseCategory.self, forKey: .category)
        folderPath = try container.decode([String].self, forKey: .folderPath)
        bodyParts = try container.decode([String].self, forKey: .bodyParts)
        equipment = try container.decode([String].self, forKey: .equipment)
        goals = try container.decode([String].self, forKey: .goals)
        durationMinutes = try container.decode(Int.self, forKey: .durationMinutes)
        intensity = try container.decode(ExerciseIntensity.self, forKey: .intensity)
        memo = try container.decodeIfPresent(String.self, forKey: .memo) ?? ""
    }

    var watchURLString: String {
        "https://www.youtube.com/watch?v=\(youtubeID)"
    }

    var isLocalVideo: Bool {
        localFileName != nil
    }

    var folderLabel: String {
        ([category.title] + folderPath).joined(separator: " > ")
    }

    static func makeFromYouTube(_ video: YouTubeVideo, defaultCategory: ExerciseCategory) -> ExerciseVideo {
        let result = ExerciseVideoClassifier.classify(title: video.title, defaultCategory: defaultCategory)
        return ExerciseVideo(
            youtubeID: video.id,
            title: video.title,
            category: result.category,
            folderPath: result.folderPath,
            bodyParts: result.bodyParts,
            equipment: result.equipment,
            goals: result.goals,
            durationMinutes: result.durationMinutes,
            intensity: result.intensity
        )
    }

    static func makeFromLocalFile(fileName: String, originalTitle: String, defaultCategory: ExerciseCategory) -> ExerciseVideo {
        let title = originalTitle.trimmed.isEmpty ? "MP4 영상" : originalTitle.trimmed
        let result = ExerciseVideoClassifier.classify(title: title, defaultCategory: defaultCategory)
        return ExerciseVideo(
            youtubeID: "local:\(UUID().uuidString)",
            localFileName: fileName,
            title: title,
            category: result.category,
            folderPath: result.folderPath,
            bodyParts: result.bodyParts,
            equipment: result.equipment,
            goals: result.goals,
            durationMinutes: result.durationMinutes,
            intensity: result.intensity
        )
    }

    static func decode(from json: String) -> [ExerciseVideo] {
        guard let data = json.data(using: .utf8), !data.isEmpty else { return [] }
        return (try? JSONDecoder().decode([ExerciseVideo].self, from: data)) ?? []
    }

    static func encode(_ videos: [ExerciseVideo]) -> String {
        guard let data = try? JSONEncoder().encode(videos) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }
}

struct ExerciseClassification {
    var category: ExerciseCategory
    var folderPath: [String]
    var bodyParts: [String]
    var equipment: [String]
    var goals: [String]
    var durationMinutes: Int
    var intensity: ExerciseIntensity
}

enum ExerciseVideoClassifier {
    static func classify(title: String, defaultCategory: ExerciseCategory) -> ExerciseClassification {
        let text = title.lowercased()
        let category = detectedCategory(in: text) ?? defaultCategory
        var folders: [String] = []
        var bodyParts: [String] = []
        var equipment: [String] = []
        var goals: [String] = []

        appendMatches(from: text, to: &bodyParts, rules: [
            ("상체", ["상체", "upper"]),
            ("하체", ["하체", "lower", "leg"]),
            ("전신", ["전신", "full body", "total body", "whole body"]),
            ("코어", ["코어", "core"]),
            ("복근", ["복근", "abs", "abdominal"]),
            ("종아리", ["종아리", "calf", "calves"]),
            ("허벅지", ["허벅지", "thigh", "quad", "hamstring"]),
            ("목", ["목", "neck"]),
            ("어깨", ["어깨", "shoulder"]),
            ("팔", ["팔", "arm"]),
            ("손목", ["손목", "wrist"]),
            ("가슴", ["가슴", "chest"]),
            ("등", ["등", "back"]),
            ("허리", ["허리", "lower back"]),
            ("고관절", ["고관절", "골반", "hip", "pelvis"])
        ])

        appendMatches(from: text, to: &equipment, rules: [
            ("맨몸", ["맨몸", "bodyweight"]),
            ("요가 매트", ["요가매트", "요가 매트", "mat"]),
            ("폼롤러", ["폼롤러", "foam roller"]),
            ("요가 블럭", ["요가블럭", "요가 블럭", "block"]),
            ("밴드", ["밴드", "band"]),
            ("덤벨", ["덤벨", "dumbbell"]),
            ("머신", ["머신", "machine"]),
            ("헬스장", ["헬스장", "gym"]),
            ("소도구", ["소도구", "prop"]),
            ("짐볼", ["짐볼", "ball"]),
            ("리포머", ["리포머", "reformer"]),
            ("매트", ["매트", "mat"]),
            ("캐딜락", ["캐딜락", "cadillac"]),
            ("체어", ["체어", "chair"]),
            ("바렐", ["바렐", "barrel"]),
            ("수영장", ["수영장", "pool"]),
            ("킥판", ["킥판", "kickboard"]),
            ("풀부이", ["풀부이", "pull buoy"]),
            ("패들", ["패들", "paddle"])
        ])

        appendMatches(from: text, to: &goals, rules: [
            ("근력", ["근력", "strength"]),
            ("유연성", ["유연성", "flexibility"]),
            ("회복", ["회복", "recovery", "릴리즈", "release"]),
            ("자세 교정", ["자세", "교정", "posture"]),
            ("기술 연습", ["기술", "드릴", "drill", "킥", "kick"]),
            ("유산소", ["유산소", "cardio"]),
            ("워밍업", ["워밍업", "warm"]),
            ("쿨다운", ["쿨다운", "운동 후", "after workout"]),
            ("다이어트", ["다이어트", "체중감량", "뱃살", "살빠", "weight loss", "fat burn"]),
            ("코어 강화", ["코어", "core"]),
            ("균형", ["균형", "밸런스", "balance"])
        ])

        if category == .swimming {
            appendMatches(from: text, to: &folders, rules: [
                ("자유형", ["자유형", "freestyle"]),
                ("배영", ["배영", "backstroke"]),
                ("평영", ["평영", "breaststroke"]),
                ("접영", ["접영", "butterfly"]),
                ("턴", ["턴", "turn"]),
                ("돌핀", ["돌핀", "dolphin"]),
                ("스타트", ["스타트", "start"])
            ])
            if goals.isEmpty { goals.append("기술 연습") }
        } else if category == .pilates {
            appendMatches(from: text, to: &folders, rules: [
                ("코어", ["코어", "core"]),
                ("골반", ["골반", "고관절", "pelvis", "hip"]),
                ("자세 교정", ["자세", "교정", "posture"]),
                ("하체", ["하체", "허벅지", "종아리", "lower"]),
                ("상체", ["상체", "어깨", "팔", "upper"]),
                ("소도구", ["소도구", "밴드", "볼", "prop", "band", "ball"]),
                ("리포머", ["리포머", "reformer"]),
                ("매트", ["매트", "mat"])
            ])
        } else if category == .yoga {
            appendMatches(from: text, to: &folders, rules: [
                ("아침 요가", ["아침", "morning"]),
                ("저녁 요가", ["저녁", "night", "evening"]),
                ("유연성", ["유연성", "flexibility"]),
                ("밸런스", ["밸런스", "균형", "balance"]),
                ("릴리즈", ["릴리즈", "release"]),
                ("호흡", ["호흡", "breath"])
            ])
        } else if category == .stretching {
            appendMatches(from: text, to: &folders, rules: [
                ("아침 스트레칭", ["아침"]),
                ("운동 전", ["운동 전", "before workout"]),
                ("운동 후", ["운동 후", "after workout", "쿨다운"]),
                ("폼롤러", ["폼롤러", "foam roller"]),
                ("목/어깨", ["목", "어깨", "neck", "shoulder"]),
                ("하체", ["하체", "종아리", "허벅지", "lower"])
            ])
        } else {
            folders = bodyParts.isEmpty ? ["전신"] : Array(bodyParts.prefix(2))
        }

        return ExerciseClassification(
            category: category,
            folderPath: folders.isEmpty ? ["미분류"] : folders.uniquePreservingOrder(),
            bodyParts: bodyParts.uniquePreservingOrder(),
            equipment: equipment.isEmpty ? ["맨몸"] : equipment.uniquePreservingOrder(),
            goals: goals.isEmpty ? ["루틴"] : goals.uniquePreservingOrder(),
            durationMinutes: detectedDuration(in: text),
            intensity: detectedIntensity(in: text)
        )
    }

    private static func detectedCategory(in text: String) -> ExerciseCategory? {
        if text.contains("수영") || text.contains("접영") || text.contains("배영") || text.contains("평영") || text.contains("자유형") || text.contains("swim") {
            return .swimming
        }
        if text.contains("스트레칭") || text.contains("stretch") || text.contains("폼롤러") {
            return .stretching
        }
        if text.contains("필라테스") || text.contains("pilates") {
            return .pilates
        }
        if text.contains("리포머") || text.contains("reformer") {
            return .pilates
        }
        if text.contains("요가") || text.contains("yoga") {
            return .yoga
        }
        if text.contains("댄스") || text.contains("dance") {
            return .dance
        }
        if text.contains("덤벨") || text.contains("헬스") || text.contains("gym") || text.contains("dumbbell") {
            return .gym
        }
        if text.contains("유산소") || text.contains("cardio") {
            return .cardio
        }
        return nil
    }

    private static func detectedDuration(in text: String) -> Int {
        let patterns = [
            #"(\d{1,3})\s*분"#,
            #"(\d{1,3})\s*mins"#,
            #"(\d{1,3})\s*(min|minute|minutes)"#
        ]

        for pattern in patterns {
            if let value = firstNumber(in: text, pattern: pattern), value > 0 {
                return min(value, 180)
            }
        }

        if text.contains("shorts") || text.contains("쇼츠") { return 1 }
        return 10
    }

    private static func detectedIntensity(in text: String) -> ExerciseIntensity {
        if text.contains("초보") || text.contains("입문") || text.contains("가벼") || text.contains("easy") || text.contains("beginner") {
            return .light
        }
        if text.contains("고강도") || text.contains("힘든") || text.contains("hard") || text.contains("advanced") || text.contains("인터벌") {
            return .hard
        }
        return .normal
    }

    private static func firstNumber(in text: String, pattern: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard
            let match = regex.firstMatch(in: text, range: range),
            let numberRange = Range(match.range(at: 1), in: text)
        else {
            return nil
        }
        return Int(text[numberRange])
    }

    private static func appendMatches(from text: String, to output: inout [String], rules: [(String, [String])]) {
        for (value, keywords) in rules where keywords.contains(where: { text.contains($0) }) {
            output.append(value)
        }
    }
}

extension Array where Element: Hashable {
    func uniquePreservingOrder() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
