import SwiftUI

struct StretchingPlanSection: View {
    let recommendation: StretchingPlanRecommendation
    let tint: Color
    let addLink: () -> Void
    let importFile: () -> Void
    let openVideo: (StretchingVideo) -> Void

    var body: some View {
        BriefingSection(title: "오늘의 스트레칭", systemImage: "figure.flexibility", tint: tint) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(recommendation.totalMinutes)분")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                        Text("/ 목표 \(recommendation.targetMinutes)분")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }

                    Text(recommendation.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if recommendation.videos.isEmpty {
                    Text("설정 탭에서 스트레칭 폴더에 mp4 또는 YouTube 링크를 추가해 주세요.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(recommendation.videos.enumerated()), id: \.element.id) { index, video in
                            Button {
                                openVideo(video)
                            } label: {
                                HStack(spacing: 12) {
                                    Text("\(index + 1)")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 24, height: 24)
                                        .background(tint)
                                        .clipShape(Circle())

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(video.title)
                                            .font(.body.weight(.semibold))
                                            .foregroundStyle(.primary)
                                        Text("\(video.durationMinutes)분 · \(video.sourceKind.title)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()
                                    Image(systemName: "play.fill")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(tint)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                HStack(spacing: 10) {
                    ActionButton(title: "링크 추가", systemImage: "link", tint: tint, action: addLink)
                    ActionButton(title: "mp4 추가", systemImage: "film", tint: tint, action: importFile)
                }
            }
        }
    }
}
