import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct YouTubeToSlideApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = JobStore()

    var body: some Scene {
        WindowGroup("YouTube to Slide") {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 1120, minHeight: 720)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Add Video...") {
                    NotificationCenter.default.post(name: .openVideoPanel, object: nil)
                }
                .keyboardShortcut("o", modifiers: [.command])

                Button("Start Processing") {
                    store.startProcessing()
                }
                .keyboardShortcut(.return, modifiers: [.command])
            }
        }
    }
}

extension Notification.Name {
    static let openVideoPanel = Notification.Name("openVideoPanel")
    static let loadDemoYouTubeURL = Notification.Name("loadDemoYouTubeURL")
}
