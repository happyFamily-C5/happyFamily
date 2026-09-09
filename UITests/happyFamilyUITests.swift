import XCTest

final class HappyFamilyUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.exists)
    }

    /// End-to-end login against the local Supabase stack: the smoke
    /// organizer account must reach the dashboard's empty state.
    ///
    /// Requires a clean keychain on the target simulator — a persisted
    /// session skips the login screen entirely. Reset first:
    ///   xcrun simctl uninstall <sim> com.academy.hendraaaa.happyFamily.debug
    ///   xcrun simctl keychain <sim> reset
    @MainActor
    func testLoginFlowWithSmokeAccount() {
        let app = XCUIApplication()
        app.launch()

        let emailField = app.textFields["nama@email.com"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 10))

        let signInButton = app.buttons["Masuk"]
        XCTAssertTrue(signInButton.waitForExistence(timeout: 5))

        emailField.tap()
        emailField.typeText("smoke.organizer.kumpul@gmail.com")

        let passwordField = app.secureTextFields["Kata sandi"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 5))
        passwordField.tap()
        passwordField.typeText("SmokeTest123!")

        signInButton.tap()

        // A valid session replaces the login screen with the dashboard,
        // whose empty state offers the create-event CTA.
        let createEventButton = app.buttons["Mulai Membuat Event"]
        XCTAssertTrue(createEventButton.waitForExistence(timeout: 20))
        XCTAssertFalse(signInButton.exists)
    }
}
