import SwiftUI

struct FolderEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var folderName = ""

    let save: (String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("폴더") {
                    TextField("예: AI, 대학, 여행", text: $folderName)
                }
            }
            .navigationTitle("폴더 추가")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { save(folderName.trimmed) }
                        .disabled(folderName.trimmed.isEmpty)
                }
            }
        }
    }
}
