import SwiftUI

struct ExerciseVideoEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let video: ExerciseVideo
    let save: (ExerciseVideo) -> Void

    @State private var title: String
    @State private var category: ExerciseCategory
    @State private var folderText: String
    @State private var bodyPartText: String
    @State private var equipmentText: String
    @State private var goalText: String
    @State private var durationMinutes: Int
    @State private var intensity: ExerciseIntensity

    init(video: ExerciseVideo, save: @escaping (ExerciseVideo) -> Void) {
        self.video = video
        self.save = save
        _title = State(initialValue: video.title)
        _category = State(initialValue: video.category)
        _folderText = State(initialValue: video.folderPath.joined(separator: ", "))
        _bodyPartText = State(initialValue: video.bodyParts.joined(separator: ", "))
        _equipmentText = State(initialValue: video.equipment.joined(separator: ", "))
        _goalText = State(initialValue: video.goals.joined(separator: ", "))
        _durationMinutes = State(initialValue: video.durationMinutes)
        _intensity = State(initialValue: video.intensity)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("기본 정보") {
                    TextField("영상 제목", text: $title, axis: .vertical)
                        .lineLimit(2...4)

                    Picker("종목", selection: $category) {
                        ForEach(ExerciseCategory.allCases) { category in
                            Label(category.title, systemImage: category.iconName).tag(category)
                        }
                    }

                    Stepper("예상 시간 \(durationMinutes)분", value: $durationMinutes, in: 1...180)

                    Picker("강도", selection: $intensity) {
                        ForEach(ExerciseIntensity.allCases) { intensity in
                            Text(intensity.title).tag(intensity)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    tagTextField("폴더", text: $folderText, placeholder: "아침 스트레칭, 목/어깨")
                    tagTextField("부위", text: $bodyPartText, placeholder: "목, 어깨, 코어")
                    tagTextField("기구", text: $equipmentText, placeholder: "맨몸, 요가 매트")
                    tagTextField("목적", text: $goalText, placeholder: "유연성, 자세 교정")
                } header: {
                    Text("분류와 태그")
                } footer: {
                    Text("쉼표나 줄바꿈으로 여러 태그를 나눠 입력할 수 있어요.")
                }
            }
            .navigationTitle("영상 태그 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        save(updatedVideo)
                        dismiss()
                    }
                    .disabled(title.trimmed.isEmpty)
                }
            }
        }
    }

    private var updatedVideo: ExerciseVideo {
        ExerciseVideo(
            id: video.id,
            youtubeID: video.youtubeID,
            localFileName: video.localFileName,
            title: title.trimmed,
            category: category,
            folderPath: tags(from: folderText, fallback: ["미분류"]),
            bodyParts: tags(from: bodyPartText),
            equipment: tags(from: equipmentText, fallback: ["맨몸"]),
            goals: tags(from: goalText, fallback: ["루틴"]),
            durationMinutes: durationMinutes,
            intensity: intensity,
            memo: video.memo
        )
    }

    private func tagTextField(_ title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField(placeholder, text: text, axis: .vertical)
                .lineLimit(1...3)
        }
        .padding(.vertical, 4)
    }

    private func tags(from text: String, fallback: [String] = []) -> [String] {
        let values = text
            .components(separatedBy: CharacterSet(charactersIn: ",\n·"))
            .map(\.trimmed)
            .filter { !$0.isEmpty }
            .uniquePreservingOrder()
        return values.isEmpty ? fallback : values
    }
}
