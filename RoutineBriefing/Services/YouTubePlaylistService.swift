import Foundation

struct YouTubePlaylistService {
    func fetchVideos(from playlistURLString: String) async throws -> [YouTubeVideo] {
        guard let feedURL = YouTubePlaylist.feedURL(from: playlistURLString) else {
            throw YouTubePlaylistError.invalidPlaylistURL
        }

        let (data, response) = try await URLSession.shared.data(from: feedURL)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw YouTubePlaylistError.requestFailed
        }

        return YouTubePlaylistFeedParser().parse(data: data)
    }
}

enum YouTubePlaylistError: LocalizedError {
    case invalidPlaylistURL
    case requestFailed

    var errorDescription: String? {
        switch self {
        case .invalidPlaylistURL:
            "YouTube 재생목록 URL을 확인해 주세요."
        case .requestFailed:
            "YouTube 재생목록을 불러오지 못했어요."
        }
    }
}

final class YouTubePlaylistFeedParser: NSObject, XMLParserDelegate {
    private var videos: [YouTubeVideo] = []
    private var currentElement = ""
    private var currentID = ""
    private var currentTitle = ""
    private var isInsideEntry = false

    func parse(data: Data) -> [YouTubeVideo] {
        videos = []
        currentElement = ""
        currentID = ""
        currentTitle = ""
        isInsideEntry = false

        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return videos
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName
        if elementName == "entry" {
            isInsideEntry = true
            currentID = ""
            currentTitle = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard isInsideEntry else { return }
        switch currentElement {
        case "yt:videoId":
            currentID += string
        case "title":
            currentTitle += string
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "entry" {
            let id = currentID.trimmed
            let title = currentTitle.trimmed
            if !id.isEmpty && !title.isEmpty {
                videos.append(YouTubeVideo(id: id, title: title))
            }
            isInsideEntry = false
        }
        currentElement = ""
    }
}
