import SwiftUI

enum RoutinePeriod: String, Codable, CaseIterable, Identifiable {
    case morning
    case lunch
    case evening

    var id: String { rawValue }

    var title: String {
        switch self {
        case .morning: "아침"
        case .lunch: "점심"
        case .evening: "저녁"
        }
    }

    var navigationTitle: String { "\(title) 루틴" }

    var headline: String {
        switch self {
        case .morning: "하루를 시작하는 자동화"
        case .lunch: "중간 점검과 리셋"
        case .evening: "하루를 닫고 내일 준비"
        }
    }

    var summary: String {
        switch self {
        case .morning: "날씨, 일정, 운동, 뉴스 흐름을 한 번에 시작해요."
        case .lunch: "점심 시간에 필요한 체크와 읽을거리를 빠르게 정리해요."
        case .evening: "저녁에는 날씨 없이 회고, 캘린더, 오디오 중심으로 정리해요."
        }
    }

    var focusTitle: String {
        switch self {
        case .morning: "오늘 준비"
        case .lunch: "점심 리셋"
        case .evening: "저녁 정리"
        }
    }

    var focusIcon: String {
        switch self {
        case .morning: "checklist"
        case .lunch: "leaf.fill"
        case .evening: "moon.zzz.fill"
        }
    }

    var tint: Color {
        switch self {
        case .morning: .orange
        case .lunch: .green
        case .evening: .indigo
        }
    }

    var focusItems: [String] {
        switch self {
        case .morning:
            ["스트레칭 영상으로 몸 깨우기", "날씨 앱에서 옷차림 확인", "오늘 일정과 뉴스 확인"]
        case .lunch:
            ["오전 진행 상황 짧게 확인", "저장할 링크는 북마크 폴더에 넣기", "오후 첫 작업 하나만 정하기"]
        case .evening:
            ["내일 첫 일정 확인", "하루 회고 한 줄 남기기", "팟캐스트나 수면 오디오 열기"]
        }
    }
}
