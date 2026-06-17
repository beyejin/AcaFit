import SwiftUI

enum AppStyle: String, CaseIterable, Identifiable {
    case calm
    case focus
    case warm

    var id: String { rawValue }

    var title: String {
        switch self {
        case .calm: "차분한 기본"
        case .focus: "집중"
        case .warm: "따뜻한 톤"
        }
    }

    var tint: Color {
        switch self {
        case .calm: .blue
        case .focus: .indigo
        case .warm: .orange
        }
    }

    var background: Color {
        switch self {
        case .calm: Color(red: 0.96, green: 0.98, blue: 1.0)
        case .focus: Color(red: 0.96, green: 0.96, blue: 0.99)
        case .warm: Color(red: 1.0, green: 0.97, blue: 0.93)
        }
    }
}
