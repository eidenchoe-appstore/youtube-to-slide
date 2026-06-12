import XCTest
@testable import YouTubeToSlide

final class OpenRouterStudyModelTests: XCTestCase {
    func testDefaultStudyModelOrderUsesNemotronAndGemmaFallback() {
        let settings = AppSettings()

        XCTAssertEqual(
            settings.studyModelIDs,
            [
                "nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free",
                "google/gemma-4-26b-a4b-it:free"
            ]
        )
    }

    func testStudyModelIDsAllowCustomModels() {
        var settings = AppSettings()
        settings.primaryStudyModelID = "custom/provider-model:free"
        settings.fallbackStudyModelID = OpenRouterStudyModel.nemotron3NanoOmni.id

        XCTAssertEqual(settings.studyModelIDs, ["custom/provider-model:free", OpenRouterStudyModel.nemotron3NanoOmni.id])
    }

    func testOpenRouterClientKeepsCustomModelsAndTrimsWhitespace() {
        let client = OpenRouterClient(
            apiKey: "test-key",
            modelIDs: ["  google/gemma-4-31b-it:free  ", "custom/provider-model:free"]
        )

        XCTAssertEqual(client.modelIDs, ["google/gemma-4-31b-it:free", "custom/provider-model:free"])
    }

    func testOpenRouterClientFallsBackToDefaultWhenModelsAreEmpty() {
        let client = OpenRouterClient(apiKey: "test-key", modelIDs: ["   "])

        XCTAssertEqual(client.modelIDs, [OpenRouterStudyModel.defaultPrimaryID])
    }
}
