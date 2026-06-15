import Foundation
import SwiftUI

struct ContentView: View {
    @AppStorage("exerciseVideosJSON") private var exerciseVideosJSON = ""
    @AppStorage("exercisePlaylistURL") private var exercisePlaylistURL = "https://www.youtube.com/watch?v=6_LYz_XxD-g&list=PLG_C87ZIUfVSnkl19ZW471UAOnn74yL0l"
    @AppStorage("defaultImportCategory") private var defaultImportCategoryRaw = ExerciseCategory.stretching.rawValue

    @State private var playlistVideos: [YouTubeVideo] = []
    @State private var playlistLoadError: String?
    @State private var selectedCategory: ExerciseCategory?
    @State private var selectedBodyPart: String?
    @State private var selectedEquipment: String?
    @State private var selectedGoal: String?
    @State private var selectedVideo: ExerciseVideo?
    @State private var editingVideo: ExerciseVideo?

    private var exerciseVideos: [ExerciseVideo] {
        get { ExerciseVideo.decode(from: exerciseVideosJSON) }
        nonmutating set { exerciseVideosJSON = ExerciseVideo.encode(newValue) }
    }

    private var defaultImportCategory: ExerciseCategory {
        get { ExerciseCategory(rawValue: defaultImportCategoryRaw) ?? .stretching }
        nonmutating set { defaultImportCategoryRaw = newValue.rawValue }
    }

    private var importedCandidates: [ExerciseVideo] {
        let savedIDs = Set(exerciseVideos.map(\.youtubeID))
        return playlistVideos
            .filter { !savedIDs.contains($0.id) }
            .map { ExerciseVideo.makeFromYouTube($0, defaultCategory: defaultImportCategory) }
    }

    private var filteredVideos: [ExerciseVideo] {
        exerciseVideos.filter { video in
            if let selectedCategory, video.category != selectedCategory { return false }
            if let selectedBodyPart, !video.bodyParts.contains(selectedBodyPart) { return false }
            if let selectedEquipment, !video.equipment.contains(selectedEquipment) { return false }
            if let selectedGoal, !video.goals.contains(selectedGoal) { return false }
            return true
        }
    }

    private var todayVideo: ExerciseVideo? {
        let videos = filteredVideos.isEmpty ? exerciseVideos : filteredVideos
        guard !videos.isEmpty else { return nil }
        let day = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        return videos[abs(day) % videos.count]
    }

    var body: some View {
        TabView {
            todayScreen
                .tabItem { Label("오늘", systemImage: "sparkles") }

            archiveScreen
                .tabItem { Label("아카이브", systemImage: "square.grid.2x2.fill") }

            importScreen
                .tabItem { Label("가져오기", systemImage: "tray.and.arrow.down.fill") }

            settingsScreen
                .tabItem { Label("설정", systemImage: "gearshape.fill") }
        }
        .tint(.blue)
        .task(id: exercisePlaylistURL) {
            await loadPlaylistVideos()
        }
        .sheet(item: $editingVideo) { video in
            ExerciseVideoEditorView(video: video) { updatedVideo in
                upsertVideo(updatedVideo)
            }
        }
    }

    private var todayScreen: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header(
                        title: "오늘 운동",
                        subtitle: "필터에 맞는 영상 중 하나를 골라 바로 시작해요."
                    )

                    filterPanel

                    if let todayVideo {
                        featuredVideoCard(todayVideo)
                    } else {
                        emptyState(
                            title: "아직 저장된 운동이 없어요",
                            subtitle: "가져오기 탭에서 재생목록 영상을 아카이브에 넣어주세요."
                        )
                    }

                    categoryOverview
                }
                .screenPadding()
            }
            .exerciseBackground()
            .navigationTitle("오늘")
            .navigationDestination(item: $selectedVideo) { video in
                ExercisePlayerScreen(video: video, relatedVideos: relatedVideos(for: video))
            }
        }
    }

    private var archiveScreen: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header(
                        title: "운동 아카이브",
                        subtitle: "종목, 부위, 기구, 목적을 조합해서 필요한 영상을 빠르게 찾아요."
                    )

                    filterPanel

                    if filteredVideos.isEmpty {
                        emptyState(
                            title: exerciseVideos.isEmpty ? "아카이브가 비어 있어요" : "필터에 맞는 영상이 없어요",
                            subtitle: exerciseVideos.isEmpty ? "YouTube 재생목록에서 영상을 가져와 보관해요." : "필터를 하나씩 해제해 보세요."
                        )
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 12)], spacing: 12) {
                            ForEach(filteredVideos) { video in
                                exerciseVideoCard(video)
                            }
                        }
                    }
                }
                .screenPadding()
            }
            .exerciseBackground()
            .navigationTitle("아카이브")
            .toolbar {
                Button("필터 초기화") {
                    clearFilters()
                }
            }
            .navigationDestination(item: $selectedVideo) { video in
                ExercisePlayerScreen(video: video, relatedVideos: relatedVideos(for: video))
            }
        }
    }

    private var importScreen: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header(
                        title: "YouTube 가져오기",
                        subtitle: "재생목록을 읽고 앱이 종목, 폴더, 태그를 먼저 분류해요."
                    )

                    VStack(alignment: .leading, spacing: 12) {
                        TextField("YouTube 재생목록 URL", text: $exercisePlaylistURL)
                            .urlFieldStyle()

                        Picker("기본 종목", selection: Binding(
                            get: { defaultImportCategory },
                            set: { defaultImportCategory = $0 }
                        )) {
                            ForEach(ExerciseCategory.allCases) { category in
                                Label(category.title, systemImage: category.iconName).tag(category)
                            }
                        }

                        HStack {
                            Label(importStatusText, systemImage: "info.circle")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)

                            Spacer()

                            Button {
                                importAllCandidates()
                            } label: {
                                Label("전체 저장", systemImage: "plus.circle.fill")
                            }
                            .disabled(importedCandidates.isEmpty)
                        }
                    }
                    .exerciseCard()

                    if importedCandidates.isEmpty {
                        emptyState(
                            title: "가져올 새 영상이 없어요",
                            subtitle: playlistLoadError ?? "재생목록 URL을 넣으면 새 영상 후보가 여기에 보여요."
                        )
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(importedCandidates) { video in
                                importCandidateRow(video)
                            }
                        }
                    }
                }
                .screenPadding()
            }
            .exerciseBackground()
            .navigationTitle("가져오기")
        }
    }

    private var settingsScreen: some View {
        NavigationStack {
            List {
                Section("기본 카테고리") {
                    ForEach(ExerciseCategory.allCases) { category in
                        categorySettingRow(category)
                    }
                }

                Section("저장 상태") {
                    LabeledContent("아카이브 영상", value: "\(exerciseVideos.count)개")
                    LabeledContent("재생목록 후보", value: "\(importedCandidates.count)개")
                }
            }
            .navigationTitle("설정")
        }
    }

    private var filterPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            filterRow(title: "종목", values: ExerciseCategory.allCases.map(\.title), selectedValue: selectedCategory?.title) { value in
                selectedCategory = ExerciseCategory.allCases.first { $0.title == value }
            }

            filterRow(title: "부위", values: ExerciseTaxonomy.bodyParts, selectedValue: selectedBodyPart) { value in
                selectedBodyPart = value
            }

            filterRow(title: "기구", values: ExerciseTaxonomy.equipment, selectedValue: selectedEquipment) { value in
                selectedEquipment = value
            }

            filterRow(title: "목적", values: ExerciseTaxonomy.goals, selectedValue: selectedGoal) { value in
                selectedGoal = value
            }
        }
        .exerciseCard()
    }

    private var categoryOverview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("카테고리")
                    .font(.title3.weight(.bold))
                Spacer()
                Text("\(exerciseVideos.count)개 영상")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 10)], spacing: 10) {
                ForEach(ExerciseCategory.allCases) { category in
                    Button {
                        selectedCategory = category
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: category.iconName)
                                .foregroundStyle(category.tint)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(category.title)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(.primary)
                                Text("\(exerciseVideos.filter { $0.category == category }.count)개")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(12)
                        .background(category.tint.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .exerciseCard()
    }

    private func filterRow(title: String, values: [String], selectedValue: String?, select: @escaping (String?) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.bold))
                Spacer()
                if selectedValue != nil {
                    Button("해제") { select(nil) }
                        .font(.caption.weight(.semibold))
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(values, id: \.self) { value in
                        Button {
                            select(selectedValue == value ? nil : value)
                        } label: {
                            Text(value)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(selectedValue == value ? .white : .primary)
                                .padding(.horizontal, 11)
                                .padding(.vertical, 8)
                                .background(selectedValue == value ? Color.blue : Color.primary.opacity(0.06))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func featuredVideoCard(_ video: ExerciseVideo) -> some View {
        Button {
            selectedVideo = video
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("추천 루틴")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(video.category.tint)
                        Text(video.title)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(video.folderLabel)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "play.fill")
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(Color.red)
                        .clipShape(Circle())
                }

                tagWrap(video.bodyParts + video.equipment + video.goals)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(video.category.tint.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(video.category.tint.opacity(0.18), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                editingVideo = video
            } label: {
                Label("태그 수정", systemImage: "tag")
            }
        }
    }

    private func exerciseVideoCard(_ video: ExerciseVideo) -> some View {
        Button {
            selectedVideo = video
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(video.category.title, systemImage: video.category.iconName)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(video.category.tint)

                    Spacer()

                    Text(video.intensity.title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }

                Text(video.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(video.folderLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                tagWrap(Array((video.bodyParts + video.equipment + video.goals).prefix(4)))
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 166, alignment: .leading)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                editingVideo = video
            } label: {
                Label("태그 수정", systemImage: "tag")
            }
        }
    }

    private func importCandidateRow(_ video: ExerciseVideo) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: video.category.iconName)
                .foregroundStyle(video.category.tint)
                .frame(width: 34, height: 34)
                .background(video.category.tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(video.title)
                    .font(.headline)
                    .lineLimit(2)
                Text(video.folderLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                tagWrap(Array((video.bodyParts + video.equipment + video.goals).prefix(5)))
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    editingVideo = video
                } label: {
                    Image(systemName: "pencil")
                        .font(.headline.weight(.bold))
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: 8))

                Button {
                    saveCandidate(video)
                } label: {
                    Image(systemName: "plus")
                        .font(.headline.weight(.bold))
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 8))
            }
        }
        .exerciseCard()
    }

    private func categorySettingRow(_ category: ExerciseCategory) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(category.title, systemImage: category.iconName)
                .font(.headline)
                .foregroundStyle(category.tint)
            Text(category.defaultFolders.joined(separator: " · "))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func tagWrap(_ values: [String]) -> some View {
        FlowLayout(spacing: 6) {
            ForEach(values.uniquePreservingOrder(), id: \.self) { value in
                Text(value)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(Capsule())
            }
        }
    }

    private func header(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
    }

    private func emptyState(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "tray")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .exerciseCard()
    }

    private var importStatusText: String {
        if let playlistLoadError { return playlistLoadError }
        if playlistVideos.isEmpty { return "재생목록을 불러오는 중이거나 비어 있어요." }
        return "새 후보 \(importedCandidates.count)개 / 전체 \(playlistVideos.count)개"
    }

    @MainActor
    private func loadPlaylistVideos() async {
        let playlistURL = exercisePlaylistURL.trimmed
        guard !playlistURL.isEmpty else {
            playlistVideos = []
            playlistLoadError = nil
            return
        }

        do {
            playlistVideos = try await YouTubePlaylistService().fetchVideos(from: playlistURL)
            playlistLoadError = nil
        } catch {
            playlistVideos = []
            playlistLoadError = error.localizedDescription
        }
    }

    private func saveCandidate(_ video: ExerciseVideo) {
        guard !exerciseVideos.contains(where: { $0.youtubeID == video.youtubeID }) else { return }
        exerciseVideos = [video] + exerciseVideos
    }

    private func upsertVideo(_ video: ExerciseVideo) {
        var videos = exerciseVideos
        if let index = videos.firstIndex(where: { $0.id == video.id || $0.youtubeID == video.youtubeID }) {
            videos[index] = video
        } else {
            videos.insert(video, at: 0)
        }
        exerciseVideos = videos
    }

    private func relatedVideos(for video: ExerciseVideo) -> [ExerciseVideo] {
        let sameCategory = exerciseVideos
            .filter { $0.category == video.category && $0.id != video.id }
            .prefix(2)
        return [video] + Array(sameCategory)
    }

    private func importAllCandidates() {
        let savedIDs = Set(exerciseVideos.map(\.youtubeID))
        exerciseVideos = importedCandidates.filter { !savedIDs.contains($0.youtubeID) } + exerciseVideos
    }

    private func clearFilters() {
        selectedCategory = nil
        selectedBodyPart = nil
        selectedEquipment = nil
        selectedGoal = nil
    }
}

private enum ExerciseTaxonomy {
    static let bodyParts = ["전신", "상체", "하체", "코어", "복근", "목", "어깨", "팔", "손목", "가슴", "등", "허리", "골반", "고관절", "허벅지", "종아리"]
    static let equipment = ["맨몸", "요가 매트", "폼롤러", "요가 블럭", "밴드", "덤벨", "머신", "헬스장", "소도구", "짐볼", "리포머", "캐딜락", "체어", "바렐", "수영장", "킥판", "풀부이", "패들"]
    static let goals = ["근력", "유연성", "회복", "자세 교정", "기술 연습", "유산소", "워밍업", "쿨다운", "다이어트", "코어 강화", "균형", "루틴"]
}

private struct ExercisePlayerScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var expandedVideoID: UUID

    let video: ExerciseVideo
    let relatedVideos: [ExerciseVideo]

    init(video: ExerciseVideo, relatedVideos: [ExerciseVideo]) {
        self.video = video
        self.relatedVideos = relatedVideos.isEmpty ? [video] : relatedVideos
        _expandedVideoID = State(initialValue: video.id)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                routineInfoCard

                VStack(alignment: .leading, spacing: 12) {
                    Text("영상")
                        .font(.headline)

                    LazyVStack(spacing: 12) {
                        ForEach(Array(relatedVideos.prefix(3).enumerated()), id: \.element.id) { index, item in
                            routineVideoCard(item, index: index + 1, isExpanded: expandedVideoID == item.id)
                        }
                    }
                }

                memoCard

                Button {
                    dismiss()
                } label: {
                    HStack {
                        Text(Date().formatted(.dateTime.year().month(.twoDigits).day(.twoDigits)))
                        Text("오늘 운동 확인")
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .padding(.bottom, 28)
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("아침 운동")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(.systemGroupedBackground), for: .navigationBar)
    }

    private var routineInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("알람 07:00", systemImage: "clock")
            Label("요일 월, 화, 수, 목, 금", systemImage: "calendar")
        }
        .font(.headline)
        .foregroundStyle(.primary)
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        }
    }

    private func routineVideoCard(_ item: ExerciseVideo, index: Int, isExpanded: Bool) -> some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.snappy) {
                    expandedVideoID = item.id
                }
            } label: {
                HStack(spacing: 14) {
                    thumbnail(for: item)
                        .frame(width: 112, height: 62)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    Text("Video \(index)")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(16)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("YouTube 영상")
                            .font(.headline)
                        Spacer()
                        Label("앱 내부 재생", systemImage: "play.rectangle")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.secondary)
                    }

                    YouTubePlayerView(videoID: item.youtubeID)
                        .aspectRatio(16 / 9, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        }
    }

    private var memoCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("메모")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                Text("🌅 아침 루틴 (약 \(video.durationMinutes)분)")
                    .font(.headline)
                Text("[\(video.category.title) · \(video.durationMinutes)분]")
                    .font(.subheadline.weight(.semibold))
                Text("• \(video.folderPath.joined(separator: ", "))")
                Text("• \(video.bodyParts.joined(separator: ", "))")
                Text("• \(video.goals.joined(separator: ", "))")
            }
            .font(.body)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func thumbnail(for video: ExerciseVideo) -> some View {
        AsyncImage(url: URL(string: "https://img.youtube.com/vi/\(video.youtubeID)/hqdefault.jpg")) { image in
            image
                .resizable()
                .scaledToFill()
        } placeholder: {
            Rectangle()
                .fill(Color.secondary.opacity(0.12))
        }
    }

}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        let rows = rows(for: subviews, width: width)
        return CGSize(width: width, height: rows.reduce(0) { $0 + $1.height } + CGFloat(max(rows.count - 1, 0)) * spacing)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = rows(for: subviews, width: bounds.width)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for item in row.items {
                item.subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(item.size))
                x += item.size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private func rows(for subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if current.width + size.width + (current.items.isEmpty ? 0 : spacing) > width, !current.items.isEmpty {
                rows.append(current)
                current = Row()
            }
            current.append(subview: subview, size: size, spacing: spacing)
        }

        if !current.items.isEmpty {
            rows.append(current)
        }
        return rows
    }

    private struct Row {
        var items: [(subview: LayoutSubview, size: CGSize)] = []
        var width: CGFloat = 0
        var height: CGFloat = 0

        mutating func append(subview: LayoutSubview, size: CGSize, spacing: CGFloat) {
            width += (items.isEmpty ? 0 : spacing) + size.width
            height = max(height, size.height)
            items.append((subview, size))
        }
    }
}

private extension View {
    func screenPadding() -> some View {
        self
            .frame(maxWidth: 980, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
    }

    func exerciseCard() -> some View {
        self
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
            }
    }

    func exerciseBackground() -> some View {
        self.background(Color(red: 0.96, green: 0.98, blue: 1.0).ignoresSafeArea())
    }
}
