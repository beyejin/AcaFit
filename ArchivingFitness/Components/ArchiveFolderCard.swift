import SwiftUI

struct ArchiveFolderCard: View {
    let folder: ArchiveFolder
    let tint: Color
    let add: () -> Void
    let delete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundStyle(tint)
                Spacer()
                Button(role: .destructive, action: delete) {
                    Image(systemName: "trash")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }

            Text(folder.name)
                .font(.headline)
                .lineLimit(1)

            Text("\(folder.items.count)개 저장됨")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let latest = folder.items.first {
                Text(latest.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Button(action: add) {
                Label("추가", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.roundedRectangle(radius: 8))
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 170, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        }
    }
}
