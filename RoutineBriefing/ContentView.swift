import Foundation
import AVKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @AppStorage("exerciseVideosJSON") private var exerciseVideosJSON = ""
    @AppStorage("exercisePlaylistURL") private var exercisePlaylistURL = "https://www.youtube.com/watch?v=6_LYz_XxD-g&list=PLG_C87ZIUfVSnkl19ZW471UAOnn74yL0l"
    @AppStorage("defaultImportCategory") private var defaultImportCategoryRaw = ExerciseCategory.stretching.rawValue
    @AppStorage("appThemeMode") private var appThemeModeRaw = AppThemeMode.system.rawValue
    @AppStorage("appAccentColor") private var appAccentColorRaw = AppAccentColor.blue.rawValue
    @AppStorage("routineTargetMinutes") private var routineTargetMinutes = 20
    @AppStorage("youtubeAPIKey") private var youtubeAPIKey = ""
    @AppStorage("customRoutinesJSON") private var customRoutinesJSON = ""
    @AppStorage("routineSelectionRaw") private var routineSelectionRaw = "auto"

    @State private var playlistVideos: [YouTubeVideo] = []
    @State private var fetchedDetails: [String: YouTubeVideoDetails] = [:]
    @State private var playlistLoadError: String?
    @State private var isLoadingPlaylist = false
    @State private var isImportingLocalVideo = false
    @State private var localVideoImportError: String?
    @State private var editingRoutine: CustomRoutine?
    @State private var selectedCategory: ExerciseCategory?
    @State private var selectedBodyPart: String?
    @State private var selectedEquipment: String?
    @State private var selectedGoal: String?
    @State private var selectedVideo: ExerciseVideo?
    @State private var archiveSelectedVideo: ExerciseVideo?
    @State private var editingVideo: ExerciseVideo?
    @State private var archiveViewMode = ArchiveViewMode.videos
    @State private var selectedArchiveFolder: String?

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
            .map { video in
                var candidate = ExerciseVideo.makeFromYouTube(video, defaultCategory: defaultImportCategory)
                if let details = fetchedDetails[video.id] {
                    candidate.durationMinutes = details.durationMinutes
                    candidate.title = details.title
                }
                return candidate
            }
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

    private var archiveFolderGroups: [(name: String, videos: [ExerciseVideo])] {
        let grouped = Dictionary(grouping: filteredVideos) { video in
            video.folderPath.first ?? "미분류"
        }
        return grouped
            .map { (name: $0.key, videos: $0.value.sorted { $0.title < $1.title }) }
            .sorted { lhs, rhs in
                if lhs.name == "미분류" { return false }
                if rhs.name == "미분류" { return true }
                return lhs.name < rhs.name
            }
    }

    private var selectedArchiveFolderVideos: [ExerciseVideo] {
        guard let selectedArchiveFolder else { return [] }
        return archiveFolderGroups.first { $0.name == selectedArchiveFolder }?.videos ?? []
    }

    private var appThemeMode: AppThemeMode {
        get { AppThemeMode(rawValue: appThemeModeRaw) ?? .system }
        nonmutating set { appThemeModeRaw = newValue.rawValue }
    }

    private var appAccentColor: AppAccentColor {
        get { AppAccentColor(rawValue: appAccentColorRaw) ?? .blue }
        nonmutating set { appAccentColorRaw = newValue.rawValue }
    }

    private var customRoutines: [CustomRoutine] {
        get { CustomRoutine.decode(from: customRoutinesJSON) }
        nonmutating set { customRoutinesJSON = CustomRoutine.encode(newValue) }
    }

    private var routineSelection: RoutineSelection {
        get { RoutineSelection.fromStorage(routineSelectionRaw) }
        nonmutating set { routineSelectionRaw = newValue.storageString }
    }

    private var todayRoutineVideos: [ExerciseVideo] {
        switch routineSelection {
        case .automatic:
            let plan = recommendationPlan(from: exerciseVideos, targetMinutes: routineTargetMinutes)
            return plan.isEmpty ? recommendationPlan(from: exerciseVideos, targetMinutes: routineTargetMinutes) : plan
        case .custom(let routineID):
            guard let routine = customRoutines.first(where: { $0.id == routineID }) else {
                return recommendationPlan(from: exerciseVideos, targetMinutes: routineTargetMinutes)
            }
            let lookup = Dictionary(uniqueKeysWithValues: exerciseVideos.map { ($0.id, $0) })
            let ordered = routine.videoIDs.compactMap { lookup[$0] }
            return ordered.isEmpty
                ? recommendationPlan(from: exerciseVideos, targetMinutes: routineTargetMinutes)
                : ordered
        }
    }

    private var todayRoutineModeLabel: String {
        switch routineSelection {
        case .automatic: "추천 루틴"
        case .custom(let id):
            customRoutines.first(where: { $0.id == id })?.name ?? "사용자 루틴"
        }
    }

    private var todayRoutineTotalMinutes: Int {
        todayRoutineVideos.reduce(0) { $0 + $1.durationMinutes }
    }

    private var todayRoutineSubtitle: String {
        guard !todayRoutineVideos.isEmpty else {
            return "설정에서 목표 루틴 시간을 정하고, 아카이브에 영상을 저장해 주세요."
        }
        if let selectedCustomRoutine {
            return "\(todayRoutineModeLabel) · \(selectedCustomRoutine.scheduleSummary) · 총 \(todayRoutineTotalMinutes)분"
        }
        return "\(todayRoutineModeLabel) · 총 \(todayRoutineTotalMinutes)분"
    }

    private var selectedCustomRoutine: CustomRoutine? {
        guard case .custom(let routineID) = routineSelection else { return nil }
        return customRoutines.first { $0.id == routineID }
    }

    private var dailySeed: Int {
        let day = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        return abs(day)
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
        .tint(appAccentColor.color)
        .preferredColorScheme(appThemeMode.colorScheme)
        .task(id: exercisePlaylistURL) {
            await loadPlaylistVideos()
        }
        .sheet(item: $editingVideo) { video in
            ExerciseVideoEditorView(video: video) { updatedVideo in
                upsertVideo(updatedVideo)
            }
        }
        .sheet(item: $editingRoutine) { routine in
            CustomRoutineEditorView(routine: routine, videos: exerciseVideos) { updatedRoutine in
                upsertRoutine(updatedRoutine)
            }
        }
        .fileImporter(
            isPresented: $isImportingLocalVideo,
            allowedContentTypes: [.mpeg4Movie, .movie],
            allowsMultipleSelection: false
        ) { result in
            importLocalVideo(result)
        }
    }

    private var todayScreen: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header(
                        title: "오늘 운동",
                        subtitle: todayRoutineSubtitle
                    )

                    if todayRoutineVideos.isEmpty {
                        emptyState(
                            title: "추천할 영상이 아직 없어요",
                            subtitle: "가져오기 탭에서 영상을 저장하면 설정한 시간에 맞춰 오늘 루틴을 구성해요."
                        )
                    } else {
                        todayRoutineSection(todayRoutineVideos)
                    }
                }
                .screenPadding()
            }
            .exerciseBackground()
            .navigationTitle("오늘")
            .navigationDestination(item: $selectedVideo) { video in
                ExercisePlayerScreen(
                    video: video,
                    relatedVideos: todayRoutineVideos,
                    routineTimeText: selectedCustomRoutine?.startTimeText,
                    routineWeekdaysText: selectedCustomRoutine?.weekdaysText
                )
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

                    Picker("아카이브 보기", selection: Binding(
                        get: { archiveViewMode },
                        set: { mode in
                            archiveViewMode = mode
                            selectedArchiveFolder = nil
                        }
                    )) {
                        ForEach(ArchiveViewMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    if filteredVideos.isEmpty {
                        emptyState(
                            title: exerciseVideos.isEmpty ? "아카이브가 비어 있어요" : "필터에 맞는 영상이 없어요",
                            subtitle: exerciseVideos.isEmpty ? "YouTube 재생목록에서 영상을 가져와 보관해요." : "필터를 하나씩 해제해 보세요."
                        )
                    } else if archiveViewMode == .videos {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 12)], spacing: 12) {
                            ForEach(filteredVideos) { video in
                                exerciseVideoCard(video)
                            }
                        }
                    } else if let selectedArchiveFolder {
                        archiveFolderDetail(name: selectedArchiveFolder, videos: selectedArchiveFolderVideos)
                    } else {
                        archiveFolderGrid
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
            .navigationDestination(item: $archiveSelectedVideo) { video in
                ArchiveVideoDetailScreen(
                    video: video,
                    save: { updatedVideo in
                        upsertVideo(updatedVideo)
                    },
                    delete: { deletedVideo in
                        deleteVideo(deletedVideo)
                    }
                )
            }
        }
    }

    private var importScreen: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header(
                        title: "영상 가져오기",
                        subtitle: "YouTube URL 또는 MP4 파일을 저장해서 오늘 루틴과 아카이브에서 사용해요."
                    )

                    VStack(alignment: .leading, spacing: 12) {
                        TextField("재생목록 / 단일 영상 / Shorts URL", text: $exercisePlaylistURL)
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

                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .center, spacing: 12) {
                            Image(systemName: "film")
                                .foregroundStyle(.blue)
                                .frame(width: 34, height: 34)
                                .background(Color.blue.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                            VStack(alignment: .leading, spacing: 4) {
                                Text("MP4 파일")
                                    .font(.headline)
                                if let localVideoImportError {
                                    Text(localVideoImportError)
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                } else {
                                    Text("기기나 iCloud Drive의 MP4를 아카이브에 저장해요.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            Button {
                                localVideoImportError = nil
                                isImportingLocalVideo = true
                            } label: {
                                Label("파일 선택", systemImage: "folder")
                            }
                            .buttonStyle(.borderedProminent)
                            .buttonBorderShape(.roundedRectangle(radius: 8))
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
                Section("화면") {
                    Picker("테마 모드", selection: Binding(
                        get: { appThemeMode },
                        set: { appThemeMode = $0 }
                    )) {
                        ForEach(AppThemeMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }

                    Picker("포인트 색상", selection: Binding(
                        get: { appAccentColor },
                        set: { appAccentColor = $0 }
                    )) {
                        ForEach(AppAccentColor.allCases) { accent in
                            Label(accent.title, systemImage: "circle.fill")
                                .foregroundStyle(accent.color)
                                .tag(accent)
                        }
                    }
                }

                Section("오늘 루틴") {
                    Stepper("추천 루틴 \(routineTargetMinutes)분", value: $routineTargetMinutes, in: 5...120, step: 5)

                    Picker("표시할 루틴", selection: Binding(
                        get: { routineSelection },
                        set: { routineSelection = $0 }
                    )) {
                        Text("추천 루틴").tag(RoutineSelection.automatic)
                        ForEach(customRoutines) { routine in
                            Text(routine.name.isEmpty ? "이름 없는 루틴" : routine.name)
                                .tag(RoutineSelection.custom(routine.id))
                        }
                    }

                    LabeledContent("오늘 표시", value: todayRoutineVideos.isEmpty ? "없음" : "\(todayRoutineVideos.count)개 · \(todayRoutineTotalMinutes)분")
                }

                Section {
                    Button {
                        editingRoutine = CustomRoutine(name: "")
                    } label: {
                        Label("새 루틴 만들기", systemImage: "plus.circle")
                    }

                    if customRoutines.isEmpty {
                        Text("아직 만든 루틴이 없어요.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(customRoutines) { routine in
                            Button {
                                editingRoutine = routine
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(routine.name.isEmpty ? "이름 없는 루틴" : routine.name)
                                            .foregroundStyle(.primary)
                                        Text("\(routine.videoIDs.count)개 영상")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onDelete { offsets in
                            var routines = customRoutines
                            let removedIDs = offsets.map { routines[$0].id }
                            routines.remove(atOffsets: offsets)
                            customRoutines = routines
                            if case .custom(let id) = routineSelection, removedIDs.contains(id) {
                                routineSelection = .automatic
                            }
                        }
                    }
                } header: {
                    Text("내 루틴")
                } footer: {
                    Text("아카이브에 저장된 영상으로 루틴을 직접 만들 수 있어요.")
                }

                Section {
                    SecureField("YouTube Data API v3 키", text: $youtubeAPIKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif

                    if !youtubeAPIKey.trimmed.isEmpty {
                        Button(role: .destructive) {
                            youtubeAPIKey = ""
                        } label: {
                            Label("API 키 지우기", systemImage: "trash")
                        }
                    }
                } header: {
                    Text("YouTube API 키")
                } footer: {
                    Text("키를 입력하면 영상 제목과 길이를 정확히 가져와요. 키는 이 기기 안에만 저장돼요.")
                }

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
                selectedArchiveFolder = nil
            }

            filterRow(title: "부위", values: ExerciseTaxonomy.bodyParts, selectedValue: selectedBodyPart) { value in
                selectedBodyPart = value
                selectedArchiveFolder = nil
            }

            filterRow(title: "기구", values: ExerciseTaxonomy.equipment, selectedValue: selectedEquipment) { value in
                selectedEquipment = value
                selectedArchiveFolder = nil
            }

            filterRow(title: "목적", values: ExerciseTaxonomy.goals, selectedValue: selectedGoal) { value in
                selectedGoal = value
                selectedArchiveFolder = nil
            }
        }
        .exerciseCard()
    }

    private func todayRoutineSection(_ videos: [ExerciseVideo]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("오늘의 추천 루틴")
                        .font(.title3.weight(.bold))
                    Text("\(videos.count)개 영상 · \(todayRoutineTotalMinutes)분")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    selectedVideo = videos.first
                } label: {
                    Label("시작", systemImage: "play.fill")
                        .font(.subheadline.weight(.bold))
                }
                .buttonStyle(.borderedProminent)
                .disabled(videos.isEmpty)
            }

            LazyVStack(spacing: 10) {
                ForEach(Array(videos.enumerated()), id: \.element.id) { index, video in
                    todayRoutineRow(video, index: index + 1)
                }
            }
        }
        .exerciseCard()
    }

    private func todayRoutineRow(_ video: ExerciseVideo, index: Int) -> some View {
        Button {
            selectedVideo = video
        } label: {
            HStack(spacing: 12) {
                thumbnail(for: video)
                    .frame(width: 92, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(index)번째 영상")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(video.category.tint)
                    Text(video.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    Text("\(video.category.title) · \(video.durationMinutes)분")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .background(Color.primary.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
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

    private var archiveFolderGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
            ForEach(archiveFolderGroups, id: \.name) { group in
                Button {
                    selectedArchiveFolder = group.name
                } label: {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundStyle(appAccentColor.color)
                                .font(.title3)
                            Spacer()
                            Text("\(group.videos.count)개")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                        }

                        Text(group.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(2)

                        Text("\(group.videos.reduce(0) { $0 + $1.durationMinutes })분")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, minHeight: 124, alignment: .leading)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func archiveFolderDetail(name: String, videos: [ExerciseVideo]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button {
                    selectedArchiveFolder = nil
                } label: {
                    Label("폴더 목록", systemImage: "chevron.left")
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: 8))

                Spacer()

                Text("\(videos.count)개 · \(videos.reduce(0) { $0 + $1.durationMinutes })분")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Label(name, systemImage: "folder.fill")
                .font(.title3.weight(.bold))
                .foregroundStyle(appAccentColor.color)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 12)], spacing: 12) {
                ForEach(videos) { video in
                    exerciseVideoCard(video)
                }
            }
        }
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
                    Label("이름/태그 수정", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    deleteVideo(video)
                } label: {
                    Label("아카이브에서 삭제", systemImage: "trash")
                }
            }
    }

    private func exerciseVideoCard(_ video: ExerciseVideo) -> some View {
        Button {
            archiveSelectedVideo = video
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
                Label("이름/태그 수정", systemImage: "pencil")
            }
            Button(role: .destructive) {
                deleteVideo(video)
            } label: {
                Label("아카이브에서 삭제", systemImage: "trash")
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

    private func thumbnail(for video: ExerciseVideo) -> some View {
        Group {
            if video.isLocalVideo {
                Rectangle()
                    .fill(Color.secondary.opacity(0.12))
                    .overlay {
                        Image(systemName: "film")
                            .foregroundStyle(.secondary)
                    }
            } else {
                AsyncImage(url: URL(string: "https://img.youtube.com/vi/\(video.youtubeID)/hqdefault.jpg")) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.12))
                        .overlay {
                            Image(systemName: "play.rectangle")
                                .foregroundStyle(.secondary)
                        }
                }
            }
        }
    }

    private func videoPlayer(for video: ExerciseVideo) -> some View {
        Group {
            if let fileName = video.localFileName, let url = LocalVideoFileStore.url(for: fileName) {
                VideoPlayer(player: AVPlayer(url: url))
            } else if video.isLocalVideo {
                unavailableLocalVideoView
            } else {
                YouTubePlayerView(videoID: video.youtubeID)
            }
        }
    }

    private var unavailableLocalVideoView: some View {
        ZStack {
            Rectangle()
                .fill(Color.secondary.opacity(0.12))
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                Text("파일을 찾을 수 없어요")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(.secondary)
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
        if isLoadingPlaylist { return "불러오는 중…" }
        if let playlistLoadError { return playlistLoadError }
        if playlistVideos.isEmpty { return "URL을 입력하면 가져올 영상 후보를 보여줘요." }
        return "새 후보 \(importedCandidates.count)개 / 전체 \(playlistVideos.count)개"
    }

    @MainActor
    private func loadPlaylistVideos() async {
        let urlText = exercisePlaylistURL.trimmed
        guard !urlText.isEmpty else {
            playlistVideos = []
            fetchedDetails = [:]
            playlistLoadError = nil
            return
        }

        isLoadingPlaylist = true
        defer { isLoadingPlaylist = false }

        let trimmedKey = youtubeAPIKey.trimmed

        // 단일 영상 URL 우선 판별
        if let videoID = YouTubePlaylist.videoID(from: urlText), YouTubePlaylist.playlistID(from: urlText) == nil {
            if !trimmedKey.isEmpty {
                do {
                    let details = try await YouTubeDataService(apiKey: trimmedKey).fetchVideoDetails(ids: [videoID])
                    fetchedDetails = Dictionary(uniqueKeysWithValues: details.map { ($0.id, $0) })
                    playlistVideos = details.map { YouTubeVideo(id: $0.id, title: $0.title) }
                    playlistLoadError = nil
                    return
                } catch {
                    playlistVideos = []
                    fetchedDetails = [:]
                    playlistLoadError = error.localizedDescription
                    return
                }
            } else {
                playlistVideos = [YouTubeVideo(id: videoID, title: "영상 \(videoID)")]
                fetchedDetails = [:]
                playlistLoadError = "API 키를 설정하면 영상 제목과 길이를 정확히 가져와요."
                return
            }
        }

        // 재생목록 URL — API 키 있으면 Data API, 없으면 RSS fallback
        if !trimmedKey.isEmpty, let playlistID = YouTubePlaylist.playlistID(from: urlText) {
            do {
                let service = YouTubeDataService(apiKey: trimmedKey)
                let ids = try await service.fetchPlaylistVideoIDs(playlistID: playlistID)
                let details = try await service.fetchVideoDetails(ids: ids)
                fetchedDetails = Dictionary(uniqueKeysWithValues: details.map { ($0.id, $0) })
                playlistVideos = details.map { YouTubeVideo(id: $0.id, title: $0.title) }
                playlistLoadError = nil
                return
            } catch {
                playlistVideos = []
                fetchedDetails = [:]
                playlistLoadError = error.localizedDescription
                return
            }
        }

        do {
            playlistVideos = try await YouTubePlaylistService().fetchVideos(from: urlText)
            fetchedDetails = [:]
            playlistLoadError = trimmedKey.isEmpty ? "API 키를 설정하면 영상 길이까지 정확히 가져와요." : nil
        } catch {
            playlistVideos = []
            fetchedDetails = [:]
            playlistLoadError = error.localizedDescription
        }
    }

    private func saveCandidate(_ video: ExerciseVideo) {
        guard !exerciseVideos.contains(where: { $0.youtubeID == video.youtubeID }) else { return }
        exerciseVideos = [video] + exerciseVideos
    }

    private func importLocalVideo(_ result: Result<[URL], Error>) {
        do {
            guard let sourceURL = try result.get().first else { return }
            let fileName = try LocalVideoFileStore.copyIntoLibrary(from: sourceURL)
            let title = sourceURL.deletingPathExtension().lastPathComponent
            let video = ExerciseVideo.makeFromLocalFile(
                fileName: fileName,
                originalTitle: title,
                defaultCategory: defaultImportCategory
            )
            exerciseVideos = [video] + exerciseVideos
            editingVideo = video
            localVideoImportError = nil
        } catch {
            localVideoImportError = error.localizedDescription
        }
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

    private func deleteVideo(_ video: ExerciseVideo) {
        if let fileName = video.localFileName {
            LocalVideoFileStore.delete(fileName: fileName)
        }
        exerciseVideos = exerciseVideos.filter { $0.id != video.id && $0.youtubeID != video.youtubeID }
        customRoutines = customRoutines.map { routine in
            var updatedRoutine = routine
            updatedRoutine.videoIDs.removeAll { $0 == video.id }
            return updatedRoutine
        }
        if archiveSelectedVideo?.id == video.id {
            archiveSelectedVideo = nil
        }
        if selectedVideo?.id == video.id {
            selectedVideo = nil
        }
    }

    private func upsertRoutine(_ routine: CustomRoutine) {
        var routines = customRoutines
        if let index = routines.firstIndex(where: { $0.id == routine.id }) {
            routines[index] = routine
        } else {
            routines.insert(routine, at: 0)
        }
        customRoutines = routines
        routineSelection = .custom(routine.id)
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
        selectedArchiveFolder = nil
    }

    private func recommendationPlan(from videos: [ExerciseVideo], targetMinutes: Int) -> [ExerciseVideo] {
        guard !videos.isEmpty else { return [] }
        let rotation = dailySeed % videos.count
        let orderedVideos = Array(videos[rotation...]) + Array(videos[..<rotation])
        var plans: [Int: [ExerciseVideo]] = [0: []]

        for video in orderedVideos {
            let duration = max(video.durationMinutes, 1)
            for (minutes, plan) in plans.sorted(by: { $0.key > $1.key }) {
                let nextMinutes = minutes + duration
                guard nextMinutes <= targetMinutes, plans[nextMinutes] == nil else { continue }
                plans[nextMinutes] = plan + [video]
            }
        }

        if let bestMinutes = plans.keys.filter({ $0 > 0 }).max() {
            return plans[bestMinutes] ?? []
        }

        return orderedVideos.prefix(1).map { $0 }
    }
}

private enum AppThemeMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "시스템"
        case .light: "라이트"
        case .dark: "다크"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

private enum AppAccentColor: String, CaseIterable, Identifiable {
    case blue
    case green
    case orange
    case pink
    case purple
    case teal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .blue: "블루"
        case .green: "그린"
        case .orange: "오렌지"
        case .pink: "핑크"
        case .purple: "퍼플"
        case .teal: "틸"
        }
    }

    var color: Color {
        switch self {
        case .blue: .blue
        case .green: .green
        case .orange: .orange
        case .pink: .pink
        case .purple: .purple
        case .teal: .teal
        }
    }
}

private enum ArchiveViewMode: String, CaseIterable, Identifiable {
    case videos
    case folders

    var id: String { rawValue }

    var title: String {
        switch self {
        case .videos: "영상"
        case .folders: "폴더"
        }
    }
}

private enum ExerciseTaxonomy {
    static let bodyParts = ["전신", "상체", "하체", "코어", "복근", "목", "어깨", "팔", "손목", "가슴", "등", "허리", "골반", "고관절", "허벅지", "종아리"]
    static let equipment = ["맨몸", "요가 매트", "폼롤러", "요가 블럭", "밴드", "덤벨", "머신", "헬스장", "소도구", "짐볼", "리포머", "캐딜락", "체어", "바렐", "수영장", "킥판", "풀부이", "패들"]
    static let goals = ["근력", "유연성", "회복", "자세 교정", "기술 연습", "유산소", "워밍업", "쿨다운", "다이어트", "코어 강화", "균형", "루틴"]
}

private struct CustomRoutineEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let routine: CustomRoutine
    let videos: [ExerciseVideo]
    let save: (CustomRoutine) -> Void

    @State private var name: String
    @State private var startDate: Date
    @State private var selectedWeekdays: Set<RoutineWeekday>
    @State private var selectedVideoIDs: Set<UUID>

    init(routine: CustomRoutine, videos: [ExerciseVideo], save: @escaping (CustomRoutine) -> Void) {
        self.routine = routine
        self.videos = videos
        self.save = save
        _name = State(initialValue: routine.name)
        _startDate = State(initialValue: Self.date(from: routine.startMinutes))
        _selectedWeekdays = State(initialValue: Set(routine.weekdays))
        _selectedVideoIDs = State(initialValue: Set(routine.videoIDs))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("루틴") {
                    TextField("루틴 이름", text: $name)
                    DatePicker("알람 시간", selection: $startDate, displayedComponents: .hourAndMinute)
                }

                Section("요일") {
                    ForEach(RoutineWeekday.displayOrder) { weekday in
                        Button {
                            toggleWeekday(weekday)
                        } label: {
                            HStack {
                                Text(weekday.shortTitle)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedWeekdays.contains(weekday) {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }

                Section("영상") {
                    if videos.isEmpty {
                        Text("아카이브에 저장된 영상이 없어요.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(videos) { video in
                            Button {
                                toggleVideo(video.id)
                            } label: {
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: selectedVideoIDs.contains(video.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selectedVideoIDs.contains(video.id) ? video.category.tint : .secondary)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(video.title)
                                            .foregroundStyle(.primary)
                                            .lineLimit(2)
                                        Text("\(video.category.title) · \(video.durationMinutes)분")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(routine.name.isEmpty ? "새 루틴" : "루틴 수정")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        save(updatedRoutine)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        !name.trimmed.isEmpty && !selectedWeekdays.isEmpty && !selectedVideoIDs.isEmpty
    }

    private var updatedRoutine: CustomRoutine {
        CustomRoutine(
            id: routine.id,
            name: name.trimmed,
            videoIDs: videos.map(\.id).filter { selectedVideoIDs.contains($0) },
            startMinutes: Self.minutes(from: startDate),
            weekdays: RoutineWeekday.displayOrder.filter { selectedWeekdays.contains($0) }
        )
    }

    private func toggleWeekday(_ weekday: RoutineWeekday) {
        if selectedWeekdays.contains(weekday) {
            selectedWeekdays.remove(weekday)
        } else {
            selectedWeekdays.insert(weekday)
        }
    }

    private func toggleVideo(_ id: UUID) {
        if selectedVideoIDs.contains(id) {
            selectedVideoIDs.remove(id)
        } else {
            selectedVideoIDs.insert(id)
        }
    }

    private static func date(from minutes: Int) -> Date {
        Calendar.current.date(
            bySettingHour: minutes / 60,
            minute: minutes % 60,
            second: 0,
            of: Date()
        ) ?? Date()
    }

    private static func minutes(from date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return ((components.hour ?? 7) * 60) + (components.minute ?? 0)
    }
}

private struct ExercisePlayerScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var expandedVideoID: UUID

    let video: ExerciseVideo
    let relatedVideos: [ExerciseVideo]
    let routineTimeText: String?
    let routineWeekdaysText: String?

    init(video: ExerciseVideo, relatedVideos: [ExerciseVideo], routineTimeText: String?, routineWeekdaysText: String?) {
        self.video = video
        self.relatedVideos = relatedVideos.isEmpty ? [video] : relatedVideos
        self.routineTimeText = routineTimeText
        self.routineWeekdaysText = routineWeekdaysText
        _expandedVideoID = State(initialValue: video.id)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if routineTimeText != nil, routineWeekdaysText != nil {
                    routineInfoCard
                }

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
            if let routineTimeText {
                Label("알람 \(routineTimeText)", systemImage: "clock")
            }
            if let routineWeekdaysText {
                Label("요일 \(routineWeekdaysText)", systemImage: "calendar")
            }
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

                    Text("\(index)번째 영상")
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

                    videoPlayer(for: item)
                        .aspectRatio(16 / 9, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    if !item.isLocalVideo, let url = URL(string: item.watchURLString) {
                        Link(destination: url) {
                            Label("YouTube 앱/사파리에서 열기", systemImage: "arrow.up.right.square")
                                .font(.subheadline.weight(.semibold))
                        }
                    }
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
        Group {
            if video.isLocalVideo {
                Rectangle()
                    .fill(Color.secondary.opacity(0.12))
                    .overlay {
                        Image(systemName: "film")
                            .foregroundStyle(.secondary)
                    }
            } else {
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
    }

    private func videoPlayer(for video: ExerciseVideo) -> some View {
        Group {
            if let fileName = video.localFileName, let url = LocalVideoFileStore.url(for: fileName) {
                VideoPlayer(player: AVPlayer(url: url))
            } else if video.isLocalVideo {
                unavailableLocalVideoView
            } else {
                YouTubePlayerView(videoID: video.youtubeID)
            }
        }
    }

    private var unavailableLocalVideoView: some View {
        ZStack {
            Rectangle()
                .fill(Color.secondary.opacity(0.12))
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                Text("파일을 찾을 수 없어요")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(.secondary)
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
        self.background(Color(.systemGroupedBackground).ignoresSafeArea())
    }
}

private struct ArchiveVideoDetailScreen: View {
    @Environment(\.dismiss) private var dismiss

    let video: ExerciseVideo
    let save: (ExerciseVideo) -> Void
    let delete: (ExerciseVideo) -> Void

    @State private var title: String
    @State private var category: ExerciseCategory
    @State private var equipmentText: String
    @State private var memo: String

    init(video: ExerciseVideo, save: @escaping (ExerciseVideo) -> Void, delete: @escaping (ExerciseVideo) -> Void) {
        self.video = video
        self.save = save
        self.delete = delete
        _title = State(initialValue: video.title)
        _category = State(initialValue: video.category)
        _equipmentText = State(initialValue: video.equipment.joined(separator: ", "))
        _memo = State(initialValue: video.memo)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                playerSection

                titleSection

                categoryCard

                equipmentCard

                memoCard
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("영상 상세")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .destructiveAction) {
                Button(role: .destructive) {
                    delete(video)
                    dismiss()
                } label: {
                    Image(systemName: "trash")
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("저장") {
                    save(updatedVideo)
                    dismiss()
                }
                .disabled(!hasChanges || title.trimmed.isEmpty)
            }
        }
    }

    private var playerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            videoPlayer
                .aspectRatio(16 / 9, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            if !video.isLocalVideo, let url = URL(string: video.watchURLString) {
                Link(destination: url) {
                    Label("YouTube 앱/사파리에서 열기", systemImage: "arrow.up.right.square")
                        .font(.subheadline.weight(.semibold))
                }
            }
        }
    }

    private var videoPlayer: some View {
        Group {
            if let fileName = video.localFileName, let url = LocalVideoFileStore.url(for: fileName) {
                VideoPlayer(player: AVPlayer(url: url))
            } else if video.isLocalVideo {
                ZStack {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.12))
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                        Text("파일을 찾을 수 없어요")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.secondary)
                }
            } else {
                YouTubePlayerView(videoID: video.youtubeID)
            }
        }
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("이름")
                .font(.headline)
            TextField("영상 이름", text: $title, axis: .vertical)
                .font(.title3.weight(.bold))
                .lineLimit(1...3)
                .textFieldStyle(.roundedBorder)
            Text("\(video.durationMinutes)분 · \(video.intensity.title)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var categoryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("카테고리")
                .font(.headline)

            Picker("카테고리", selection: $category) {
                ForEach(ExerciseCategory.allCases) { value in
                    Label(value.title, systemImage: value.iconName).tag(value)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var equipmentCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("운동 도구")
                .font(.headline)

            TextField("맨몸, 요가 매트", text: $equipmentText, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.roundedBorder)

            Text("쉼표로 여러 도구를 나눠 입력할 수 있어요.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var memoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("메모")
                .font(.headline)

            TextEditor(text: $memo)
                .frame(minHeight: 140)
                .padding(8)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var parsedEquipment: [String] {
        let values = equipmentText
            .components(separatedBy: CharacterSet(charactersIn: ",\n·"))
            .map(\.trimmed)
            .filter { !$0.isEmpty }
            .uniquePreservingOrder()
        return values.isEmpty ? ["맨몸"] : values
    }

    private var updatedVideo: ExerciseVideo {
        ExerciseVideo(
            id: video.id,
            youtubeID: video.youtubeID,
            localFileName: video.localFileName,
            title: title.trimmed,
            category: category,
            folderPath: video.folderPath,
            bodyParts: video.bodyParts,
            equipment: parsedEquipment,
            goals: video.goals,
            durationMinutes: video.durationMinutes,
            intensity: video.intensity,
            memo: memo
        )
    }

    private var hasChanges: Bool {
        title.trimmed != video.title
            || category != video.category
            || parsedEquipment != video.equipment
            || memo != video.memo
    }
}
