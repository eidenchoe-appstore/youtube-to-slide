import XCTest
@testable import YouTubeToSlide

final class OpenRouterStudyModelTests: XCTestCase {
    func testDefaultStudyModelOrderUsesGemmaFallback() {
        let settings = AppSettings()

        XCTAssertEqual(
            settings.studyModelIDs,
            [
                "google/gemma-4-31b-it:free",
                "google/gemma-4-26b-a4b-it:free"
            ]
        )
    }

    func testStudyModelIDsFilterUnavailableModels() {
        var settings = AppSettings()
        settings.primaryStudyModelID = "nvidia/llama-nemotron-rerank-vl-1b-v2:free"
        settings.fallbackStudyModelID = OpenRouterStudyModel.nemotron3NanoOmni.id

        XCTAssertEqual(settings.studyModelIDs, [OpenRouterStudyModel.nemotron3NanoOmni.id])
    }

    func testOpenRouterClientFallsBackToDefaultWhenModelsAreUnavailable() {
        let client = OpenRouterClient(
            apiKey: "test-key",
            modelIDs: ["nvidia/llama-nemotron-rerank-vl-1b-v2:free"]
        )

        XCTAssertEqual(client.modelIDs, [OpenRouterStudyModel.gemma31B.id])
    }
}
