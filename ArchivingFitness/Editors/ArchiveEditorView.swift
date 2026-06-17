import SwiftUI

struct ArchiveEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var url = ""
    @State private var note = ""
    @State private var selectedFolderID: UUID?

    let folders: [ArchiveFolder]
    let save: (ArchiveItem, UUID) -> Void

    init(folders: [ArchiveFolder], selectedFolderID: UUID?, save: @escaping (ArchiveItem, UUID) -> Void) {
        self.folders = folders
        _selectedFolderID = State(initialValue: selectedFolderID ?? folders.first?.id)
        self.save = save
    }

    private var canSave: Bool {
        selectedFolderID != nil && !title.trimmed.isEmpty && URL(string: url.trimmed) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("저장 위치") {
                    Picker("폴더", selection: $selectedFolderID) {
                        ForEach(folders) { folder in
                            Text(folder.name).tag(Optional(folder.id))
                        }
                    }
                }

                Section("링크") {
                    TextField("제목", text: $title)
                    TextField("URL", text: $url)
                        .urlFieldStyle()
                    TextField("메모", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("아카이브 추가")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        guard let selectedFolderID else { return }
                        save(ArchiveItem(title: title.trimmed, url: url.trimmed, note: note.trimmed), selectedFolderID)
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}
