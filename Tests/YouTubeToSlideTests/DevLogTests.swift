import XCTest
@testable import YouTubeToSlide

final class DevLogTests: XCTestCase {
    @MainActor
    func testMessageIsCapturedInDevLog() {
        let store = JobStore()
        store.clearDevLogs()

        store.addYouTubeURL("not-a-url")

        XCTAssertTrue(
            store.devLogEntries.contains {
                $0.level == .warning && $0.message.contains("Enter a full YouTube URL")
            }
        )
        XCTAssertTrue(store.devLogText.contains("[WARN]"))
    }

    @MainActor
    func testAddedJobIsCapturedInDevLog() {
        let store = JobStore()
        store.clearDevLogs()

        store.addYouTubeURL("https://www.youtube.com/watch?v=MxGW2WurKuM")

        XCTAssertTrue(
            store.devLogEntries.contains {
                $0.level == .info && $0.message.contains("Added YouTube job")
            }
        )
    }
}
