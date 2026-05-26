import XCTest

final class SkyTrailsUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["IS_UI_TESTING"] = "YES"
        app.launch()
    }

    func testAppLaunchAndTabBar() throws {
        let app = XCUIApplication()
        
        // Assert RootTabBarController's tab bar exists and is visible
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5.0), "The tab bar should exist and be visible after launching the app.")
        
        // Assert the three tabs exist
        let homeTab = tabBar.buttons["Home"]
        let watchlistTab = tabBar.buttons["Watchlist"]
        let identificationTab = tabBar.buttons["Identification"]
        
        XCTAssertTrue(homeTab.exists, "The Home tab should exist.")
        XCTAssertTrue(watchlistTab.exists, "The Watchlist tab should exist.")
        XCTAssertTrue(identificationTab.exists, "The Identification tab should exist.")
    }

    func testWatchlistAuthModalPresentation() throws {
        let app = XCUIApplication()
        
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5.0))
        
        let watchlistTab = tabBar.buttons["Watchlist"]
        XCTAssertTrue(watchlistTab.exists)
        
        // Tap the Watchlist tab. This requires authentication and should present the login/onboarding flow modal.
        watchlistTab.tap()
        
        // Verify that the authentication flow modal (StartViewController) is presented.
        // The segment outlet control should be visible.
        let segmentedControl = app.segmentedControls.firstMatch
        XCTAssertTrue(segmentedControl.waitForExistence(timeout: 5.0), "Tapping Watchlist as an unauthenticated guest should present the login segmented control modal.")
        
        // Assert the segment control has two options
        XCTAssertEqual(segmentedControl.buttons.count, 2)
        
        // Try dismissing the modal using the close button "xmark.circle.fill"
        let closeButton = app.buttons["xmark.circle.fill"]
        if closeButton.exists {
            closeButton.tap()
        } else {
            // Fallback for dismissing page sheet via downward swipe
            app.swipeDown()
        }
        
        // Assert we returned back cleanly and tab bar is visible again
        XCTAssertTrue(tabBar.exists)
    }

    func testIdentificationAuthModalPresentation() throws {
        let app = XCUIApplication()
        
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5.0))
        
        let identificationTab = tabBar.buttons["Identification"]
        XCTAssertTrue(identificationTab.exists)
        
        // Tap the Identification tab. This requires authentication and should present the login modal.
        identificationTab.tap()
        
        let segmentedControl = app.segmentedControls.firstMatch
        XCTAssertTrue(segmentedControl.waitForExistence(timeout: 5.0), "Tapping Identification as an unauthenticated guest should present the login modal.")
        
        let closeButton = app.buttons["xmark.circle.fill"]
        if closeButton.exists {
            closeButton.tap()
        } else {
            app.swipeDown()
        }
        
        XCTAssertTrue(tabBar.exists)
    }
}
