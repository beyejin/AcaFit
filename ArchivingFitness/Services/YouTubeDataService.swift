import Foundation

struct YouTubeVideoDetails: Identifiable, Equatable {
    let id: String
    let title: String
    let durationMinutes: Int
}

enum YouTubeDataError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case apiKeyInvalid
    case quotaExceeded
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "YouTube API 키가 설정되어 있지 않아요. 설정에서 입력해 주세요."
        case .invalidResponse:
            "YouTube 응답을 해석하지 못했어요."
        case .apiKeyInvalid:
            "YouTube API 키가 올바르지 않아요."
        case .quotaExceeded:
            "오늘의 YouTube API 사용량을 초과했어요."
        case .requestFailed(let message):
            "YouTube API 요청 실패: \(message)"
        }
    }
}

struct YouTubeDataService {
    let apiKey: String

    func fetchVideoDetails(ids: [String]) async throws -> [YouTubeVideoDetails] {
        guard !apiKey.trimmed.isEmpty else { throw YouTubeDataError.missingAPIKey }
        guard !ids.isEmpty else { return [] }

        var results: [YouTubeVideoDetails] = []
        for chunk in ids.chunked(into: 50) {
            let response: VideosListResponse = try await get(
                path: "videos",
                queryItems: [
                    URLQueryItem(name: "part", value: "snippet,contentDetails"),
                    URLQueryItem(name: "id", value: chunk.joined(separator: ","))
                ]
            )

            for item in response.items {
                results.append(
                    YouTubeVideoDetails(
                        id: item.id,
                        title: item.snippet.title,
                        durationMinutes: parseISO8601DurationToMinutes(item.contentDetails.duration)
                    )
                )
            }
        }

        let order = Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($1, $0) })
        return results.sorted { (order[$0.id] ?? .max) < (order[$1.id] ?? .max) }
    }

    func fetchPlaylistVideoIDs(playlistID: String) async throws -> [String] {
        guard !apiKey.trimmed.isEmpty else { throw YouTubeDataError.missingAPIKey }

        var ids: [String] = []
        var pageToken: String? = nil
        repeat {
            var queryItems = [
                URLQueryItem(name: "part", value: "contentDetails"),
                URLQueryItem(name: "playlistId", value: playlistID),
                URLQueryItem(name: "maxResults", value: "50")
            ]
            if let pageToken { queryItems.append(URLQueryItem(name: "pageToken", value: pageToken)) }

            let response: PlaylistItemsResponse = try await get(
                path: "playlistItems",
                queryItems: queryItems
            )

            ids.append(contentsOf: response.items.map(\.contentDetails.videoId))
            pageToken = response.nextPageToken
        } while pageToken != nil

        return ids
    }

    private func get<Response: Decodable>(path: String, queryItems: [URLQueryItem]) async throws -> Response {
        var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/\(path)")
        components?.queryItems = queryItems + [URLQueryItem(name: "key", value: apiKey)]
        guard let url = components?.url else { throw YouTubeDataError.invalidResponse }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw YouTubeDataError.invalidResponse
        }

        if (200...299).contains(httpResponse.statusCode) {
            do {
                return try JSONDecoder().decode(Response.self, from: data)
            } catch {
                throw YouTubeDataError.invalidResponse
            }
        }

        if let errorBody = try? JSONDecoder().decode(GoogleErrorResponse.self, from: data) {
            let reason = errorBody.error.errors?.first?.reason ?? ""
            if reason == "keyInvalid" || reason == "badRequest" {
                throw YouTubeDataError.apiKeyInvalid
            }
            if reason == "quotaExceeded" || reason == "dailyLimitExceeded" || reason == "rateLimitExceeded" {
                throw YouTubeDataError.quotaExceeded
            }
            throw YouTubeDataError.requestFailed(errorBody.error.message)
        }

        throw YouTubeDataError.requestFailed("HTTP \(httpResponse.statusCode)")
    }
}

private struct VideosListResponse: Decodable {
    let items: [Item]

    struct Item: Decodable {
        let id: String
        let snippet: Snippet
        let contentDetails: ContentDetails
    }

    struct Snippet: Decodable {
        let title: String
    }

    struct ContentDetails: Decodable {
        let duration: String
    }
}

private struct PlaylistItemsResponse: Decodable {
    let items: [Item]
    let nextPageToken: String?

    struct Item: Decodable {
        let contentDetails: ContentDetails
    }

    struct ContentDetails: Decodable {
        let videoId: String
    }
}

private struct GoogleErrorResponse: Decodable {
    let error: ErrorBody

    struct ErrorBody: Decodable {
        let code: Int
        let message: String
        let errors: [ErrorDetail]?
    }

    struct ErrorDetail: Decodable {
        let reason: String?
    }
}

private func parseISO8601DurationToMinutes(_ duration: String) -> Int {
    let pattern = #"PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return 0 }
    let range = NSRange(duration.startIndex..<duration.endIndex, in: duration)
    guard let match = regex.firstMatch(in: duration, range: range) else { return 0 }

    func group(_ index: Int) -> Int {
        guard let r = Range(match.range(at: index), in: duration) else { return 0 }
        return Int(duration[r]) ?? 0
    }

    let hours = group(1)
    let minutes = group(2)
    let seconds = group(3)
    let total = hours * 60 + minutes + (seconds >= 30 ? 1 : 0)
    return max(total, 1)
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
