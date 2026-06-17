import SwiftUI

struct AutomationSystemRow: View {
    let system: AutomationSystem
    let tint: Color
    let open: () -> Void
    let delete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: open) {
                Image(systemName: "play.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(tint)
                    .clipShape(Circle())
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(system.name)
                    .font(.body.weight(.semibold))
                if !system.note.isEmpty {
                    Text(system.note)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(system.launchURL)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Button(role: .destructive, action: delete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
        }
    }
}
