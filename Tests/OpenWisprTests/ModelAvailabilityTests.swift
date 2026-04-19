import XCTest
@testable import OpenWisprLib

final class ModelAvailabilityTests: XCTestCase {

    func testAllSupportedModelURLsAreReachable() async throws {
        for model in Config.supportedModels {
            let urlString = "\(ModelDownloader.baseURL)/ggml-\(model).bin"
            let url = try XCTUnwrap(URL(string: urlString), "Invalid URL for model '\(model)'")

            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"

            let (_, response) = try await URLSession.shared.data(for: request)
            let httpResponse = try XCTUnwrap(response as? HTTPURLResponse)
            XCTAssertEqual(
                httpResponse.statusCode, 200,
                "Model '\(model)' returned \(httpResponse.statusCode) at \(urlString)"
            )
        }
    }
}
