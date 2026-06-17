import SwiftUI
import WebKit

#if os(iOS)
struct YouTubePlayerView: UIViewRepresentable {
    let videoID: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.isOpaque = false
        webView.backgroundColor = .black
        loadPlayer(in: webView, coordinator: context.coordinator)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        guard context.coordinator.videoID != videoID else { return }
        loadPlayer(in: uiView, coordinator: context.coordinator)
    }
}
#else
struct YouTubePlayerView: NSViewRepresentable {
    let videoID: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        loadPlayer(in: webView, coordinator: context.coordinator)
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        guard context.coordinator.videoID != videoID else { return }
        loadPlayer(in: nsView, coordinator: context.coordinator)
    }
}
#endif

extension YouTubePlayerView {
    final class Coordinator: NSObject, WKNavigationDelegate {
        var videoID: String?

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard navigationAction.targetFrame?.isMainFrame == true else {
                decisionHandler(.allow)
                return
            }

            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            if url.scheme == "about" {
                decisionHandler(.allow)
                return
            }

            if let host = url.host?.lowercased(),
               host.contains("youtube") || host.contains("youtube-nocookie.com") || host.contains("youtu.be") || host.contains("ytimg.com") || host.contains("googlevideo.com") || host.contains("gstatic.com") {
                decisionHandler(.allow)
                return
            }

            decisionHandler(.cancel)
        }
    }

    static func embedHTML(videoID: String) -> String {
        let embedOrigin = "https://www.youtube-nocookie.com"
        let embedURLString = "\(embedOrigin)/embed/\(videoID)?playsinline=1&rel=0&modestbranding=1&iv_load_policy=3&enablejsapi=1&origin=\(embedOrigin)"
        return """
        <!doctype html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <meta name="referrer" content="strict-origin-when-cross-origin">
            <style>
                html, body {
                    margin: 0;
                    width: 100%;
                    height: 100%;
                    overflow: hidden;
                    background: #000;
                }
                iframe {
                    width: 100%;
                    height: 100%;
                    border: 0;
                }
            </style>
        </head>
        <body>
            <iframe
                src="\(embedURLString)"
                title="YouTube video player"
                allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
                allowfullscreen
                referrerpolicy="strict-origin-when-cross-origin">
            </iframe>
        </body>
        </html>
        """
    }

    func loadPlayer(in webView: WKWebView, coordinator: Coordinator) {
        coordinator.videoID = videoID
        let html = Self.embedHTML(videoID: videoID)
        webView.loadHTMLString(html, baseURL: URL(string: "https://www.youtube-nocookie.com"))
    }
}
