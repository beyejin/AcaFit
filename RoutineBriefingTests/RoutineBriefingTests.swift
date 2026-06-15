//
//  RoutineBriefingTests.swift
//  RoutineBriefingTests
//
//  Created by 한예진 on 6/15/26.
//

import Foundation
import Testing
@testable import RoutineBriefing

struct RoutineBriefingTests {

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

}
