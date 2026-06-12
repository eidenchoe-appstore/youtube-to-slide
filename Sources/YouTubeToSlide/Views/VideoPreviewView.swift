import AVKit
import SwiftUI
import WebKit

struct VideoPreviewView: View {
    var job: ExtractionJob

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                Color.secondary.opacity(0.10)

                switch job.inputType {
                case .localVideo:
                    LocalVideoPlayerView(url: job.sourceURL ?? URL(fileURLWithPath: job.source))
                case .youtube:
                    if let videoID = youtubeVideoID {
                        YouTubeEmbedView(videoID: videoID)
                    } else {
                        unavailablePreview
                    }
                }
            }
            .aspectRatio(16 / 9, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.secondary.opacity(0.16))
            }

            Text(job.title)
                .font(.callout.weight(.medium))
                .lineLimit(1)
            Text(job.source)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private var youtubeVideoID: String? {
        if let videoID = job.youtubePreview?.videoID {
            return videoID
        }
        guard let url = URL(string: job.source) else {
            return nil
        }
        return YouTubeURLParser.videoID(from: url)
    }

    private var unavailablePreview: some View {
        VStack(spacing: 8) {
            Image(systemName: "play.rectangle")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Preview unavailable")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}

private struct LocalVideoPlayerView: View {
    var url: URL
    @State private var player: AVPlayer?

    var body: some View {
        Group {
            if let player {
                VideoPlayer(player: player)
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if player == nil {
                player = AVPlayer(url: url)
            }
        }
        .onDisappear {
            player?.pause()
        }
    }
}

private struct YouTubeEmbedView: NSViewRepresentable {
    var videoID: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsAirPlayForMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        let webView = WKWebView(frame: .zero, configuration: configuration)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.loadedVideoID != videoID else {
            return
        }
        context.coordinator.loadedVideoID = videoID

        let escapedVideoID = videoID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? videoID
        let html = """
        <!doctype html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
        html,body{margin:0;width:100%;height:100%;background:#000;overflow:hidden}
        iframe{position:absolute;inset:0;width:100%;height:100%;border:0}
        </style>
        </head>
        <body>
        <iframe
          src="https://www.youtube.com/embed/\(escapedVideoID)"
          title="YouTube video preview"
          allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
          allowfullscreen>
        </iframe>
        </body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: URL(string: "https://www.youtube.com"))
    }

    final class Coordinator {
        var loadedVideoID: String?
    }
}
