//
//  ArchivingFitnessTests.swift
//  ArchivingFitnessTests
//
//  Created by 한예진 on 6/15/26.
//

import Foundation
import Testing
@testable import ArchivingFitness

struct ArchivingFitnessTests {

    @Test func extractsPlaylistIDFromYouTubePlaylistURL() throws {
        let url = "https://www.youtube.com/watch?v=6_LYz_XxD-g&list=PLG_C87ZIUfVSnkl19ZW471UAOnn74yL0l"

        #expect(YouTubePlaylist.playlistID(from: url) == "PLG_C87ZIUfVSnkl19ZW471UAOnn74yL0l")
    }

    @Test func recommendsSameVideoForSameDate() throws {
        let videos = [
            YouTubeVideo(id: "a", title: "A"),
            YouTubeVideo(id: "b", title: "B"),
            YouTubeVideo(id: "c", title: "C")
        ]
        let date = try #require(Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 6, day: 15)))

        #expect(YouTubePlaylist.recommendedVideo(from: videos, on: date)?.id == "b")
    }

    @Test func classifiesSwimmingDolphinVideo() throws {
        let video = ExerciseVideo.makeFromYouTube(
            YouTubeVideo(id: "swim", title: "접영 돌핀킥 교정 루틴"),
            defaultCategory: .swimming
        )

        #expect(video.category == .swimming)
        #expect(video.folderPath.contains("접영"))
        #expect(video.folderPath.contains("돌핀"))
        #expect(video.goals.contains("기술 연습"))
    }

    @Test func classifiesFoamRollerCalfVideo() throws {
        let video = ExerciseVideo.makeFromYouTube(
            YouTubeVideo(id: "calf", title: "폼롤러 종아리 운동 후 스트레칭"),
            defaultCategory: .stretching
        )

        #expect(video.category == .stretching)
        #expect(video.bodyParts.contains("종아리"))
        #expect(video.equipment.contains("폼롤러"))
        #expect(video.goals.contains("쿨다운"))
    }

    @Test func customRoutineKeepsDefaultWeekdayScheduleWhenDecodedFromOldStorage() throws {
        let id = UUID()
        let json = """
        [{"id":"\(id.uuidString)","name":"아침 루틴","videoIDs":[]}]
        """

        let routine = try #require(CustomRoutine.decode(from: json).first)

        #expect(routine.startMinutes == 420)
        #expect(routine.weekdays == [.monday, .tuesday, .wednesday, .thursday, .friday])
        #expect(routine.scheduleSummary == "07:00 · 월, 화, 수, 목, 금")
    }

    @Test func customRoutineEncodesSchedule() throws {
        let routine = CustomRoutine(
            name: "저녁 루틴",
            videoIDs: [],
            startMinutes: 1260,
            weekdays: [.monday, .wednesday, .friday]
        )

        let decoded = try #require(CustomRoutine.decode(from: CustomRoutine.encode([routine])).first)

        #expect(decoded.startMinutes == 1260)
        #expect(decoded.weekdays == [.monday, .wednesday, .friday])
        #expect(decoded.scheduleSummary == "21:00 · 월, 수, 금")
    }

    @Test func oldAllVideosRoutineSelectionFallsBackToAutomaticRecommendation() throws {
        #expect(RoutineSelection.fromStorage("all") == .automatic)
        #expect(RoutineSelection.automatic.storageString == "auto")
    }

    @Test func createsLocalMP4ExerciseVideo() throws {
        let video = ExerciseVideo.makeFromLocalFile(
            fileName: "local-video.mp4",
            originalTitle: "아침 스트레칭",
            defaultCategory: .stretching
        )

        #expect(video.isLocalVideo)
        #expect(video.localFileName == "local-video.mp4")
        #expect(video.youtubeID.hasPrefix("local:"))
        #expect(video.title == "아침 스트레칭")
        #expect(video.category == .stretching)
    }

    @Test func youtubeEmbedHTMLIncludesReferrerPolicyAndOrigin() throws {
        let html = YouTubePlayerView.embedHTML(videoID: "abc123")

        #expect(html.contains("referrerpolicy=\"strict-origin-when-cross-origin\""))
        #expect(html.contains("origin=https://www.youtube-nocookie.com"))
        #expect(html.contains("https://www.youtube-nocookie.com/embed/abc123"))
    }

    @Test func autoFillsPilatesReformerMetadataFromImportedTitle() throws {
        let video = ExerciseVideo.makeFromYouTube(
            YouTubeVideo(id: "reformer", title: "20분 리포머 필라테스 코어 루틴"),
            defaultCategory: .stretching
        )

        #expect(video.category == .pilates)
        #expect(video.folderPath.contains("리포머"))
        #expect(video.bodyParts.contains("코어"))
        #expect(video.equipment.contains("리포머"))
        #expect(video.durationMinutes == 20)
    }

    @Test func archiveFolderDisplayModesExposeFileAppStyleOptions() throws {
        #expect(ArchiveFolderDisplayMode.allCases.map(\.title) == ["아이콘", "목록", "계층", "갤러리"])
        #expect(ArchiveFolderDisplayMode(rawValue: "unknown") == nil)
        #expect(ArchiveFolderDisplayMode.icons.systemImage == "square.grid.2x2")
        #expect(ArchiveFolderDisplayMode.list.systemImage == "list.bullet")
        #expect(ArchiveFolderDisplayMode.hierarchy.systemImage == "list.bullet.indent")
        #expect(ArchiveFolderDisplayMode.gallery.systemImage == "rectangle.grid.1x2")
    }

}
