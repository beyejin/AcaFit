import SwiftUI

struct AutomationEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var launchURL = ""
    @State private var note = ""
    @State private var period: RoutinePeriod

    let save: (AutomationSystem) -> Void

    init(defaultPeriod: RoutinePeriod, save: @escaping (AutomationSystem) -> Void) {
        _period = State(initialValue: defaultPeriod)
        self.save = save
    }

    private var canSave: Bool {
        !name.trimmed.isEmpty && URL(string: launchURL.trimmed) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("언제 실행할까요?") {
                    Picker("시간대", selection: $period) {
                        ForEach(RoutinePeriod.allCases) { period in
                            Text(period.title).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("자동화") {
                    TextField("이름", text: $name)
                    TextField("열 URL 또는 앱 URL", text: $launchURL)
                        .urlFieldStyle()
                    TextField("메모", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("자동화 추가")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        save(AutomationSystem(period: period, name: name.trimmed, launchURL: launchURL.trimmed, note: note.trimmed))
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}
