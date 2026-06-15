import Foundation

struct YouTubeVideo: Identifiable, Equatable {
    let id: String
    let title: String

    var watchURLString: String {
        "https://www.youtube.com/watch?v=\(id)"
    }
}

enum YouTubePlaylist {
    static func playlistID(from urlString: String) -> String? {
        guard let components = URLComponents(string: urlString.trimmed) else { return nil }
        return components.queryItems?.first { $0.name == "list" }?.value
    }

    static func feedURL(from playlistURLString: String) -> URL? {
        guard let playlistID = playlistID(from: playlistURLString) else { return nil }
        return URL(string: "https://www.youtube.com/feeds/videos.xml?playlist_id=\(playlistID)")
    }

    static func recommendedVideo(from videos: [YouTubeVideo], on date: Date = Date()) -> YouTubeVideo? {
        guard !videos.isEmpty else { return nil }
        let day = Calendar(identifier: .gregorian).ordinality(of: .day, in: .era, for: date) ?? 0
        return videos[abs(day + 2) % videos.count]
    }
}
