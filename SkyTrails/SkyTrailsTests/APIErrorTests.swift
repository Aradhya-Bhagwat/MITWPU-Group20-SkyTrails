import XCTest
@testable import SkyTrails

final class APIErrorTests: XCTestCase {
    func testUnauthorizedErrorHasUserFriendlyDescription() {
        XCTAssertEqual(
            APIError.unauthorized.errorDescription,
            "The prediction service rejected the request."
        )
    }

    func testDecodingErrorIncludesDetails() {
        let error = APIError.decodingError("Missing field at payload.items")
        XCTAssertEqual(
            error.errorDescription,
            "The prediction response format was unexpected. Missing field at payload.items"
        )
    }

    func testLocationAccessDeniedHasRecoverySuggestion() {
        XCTAssertEqual(
            LocationService.LocationError.locationAccessDenied.recoverySuggestion,
            "Enable location access in Settings, or search for a place manually."
        )
    }
}
