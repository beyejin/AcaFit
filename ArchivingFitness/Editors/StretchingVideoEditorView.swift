import SwiftUI

struct StretchingVideoEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: StretchingVideoDraft

    let save: (StretchingVideo) -> Void

    init(draft: StretchingVideoDraft, save: @escaping (StretchingVideo) -> Void) {
        _draft = State(initialValue: draft)
        self.save = save
    }

    private var canSave: Bool {
        !draft.title.trimmed.isEmpty && draft.durationMinutes > 0 && !draft.sourceValue.trimmed.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("영상 종류") {
                    Picker("종류", selection: $draft.sourceKind) {
                        ForEach(StretchingVideo.SourceKind.allCases) { kind in
                            Label(kind.title, systemImage: kind.iconName).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("영상 정보") {
                    TextField("제목", text: $draft.title)
                    Stepper("길이 \(draft.durationMinutes)분", value: $draft.durationMinutes, in: 1...60)
                    TextField(sourcePlaceholder, text: $draft.sourceValue)
                        .urlFieldStyle()
                        .disabled(draft.sourceKind == .localFile)
                }
            }
            .navigationTitle("스트레칭 영상")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        save(draft.makeVideo())
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private var sourcePlaceholder: String {
        switch draft.sourceKind {
        case .youtube:
            "https://www.youtube.com/watch?v=..."
        case .remoteMP4:
            "https://example.com/stretching.mp4"
        case .localFile:
            "가져온 파일"
        }
    }
}
