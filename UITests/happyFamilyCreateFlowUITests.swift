import XCTest

/// End-to-end create → persist → edit → delete draft flow against the
/// configured backend (staging Secrets.xcconfig), using a freshly provisioned
/// organizer account (KUMPUL_UI_EMAIL / KUMPUL_UI_PASSWORD test-runner env).
/// Proves the CreatingView → DashboardModel → /operations integration,
/// offline-queue flush on relaunch, and cache-backed listing.
///
/// Requires a clean keychain on the target simulator for the first login —
/// a persisted session skips the login screen entirely:
///   xcrun simctl keychain <sim> reset
final class HappyFamilyCreateFlowUITests: XCTestCase {
    /// The account must already have an active workspace, since the app's
    /// register screens are local-only.
    private let email = ProcessInfo.processInfo.environment["KUMPUL_UI_EMAIL"]
        ?? "smoke.organizer.kumpul@gmail.com"
    private let password = ProcessInfo.processInfo.environment["KUMPUL_UI_PASSWORD"]
        ?? "SmokeTest123!"

    @MainActor
    func testCreatePersistEditDeleteDraftFlow() {
        let app = XCUIApplication()
        app.launch()
        let eventName = "UI E2E \(Int(Date().timeIntervalSince1970))"
        let editedName = "\(eventName) EDITED"

        loginIfNeeded(app)

        openCreateFlow(app)

        // Step 1 — basic info (banner skipped; upload is covered by the
        // staging admin-banner contract check).
        let nameField = app.textFields["Cth: Ecoprint Festival 2026"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 15), "step 1 name field missing")
        nameField.tap()
        nameField.typeText(eventName)
        app.swipeUp() // dismiss the keyboard before tapping the footer button
        tapLabeled(app, "Lanjut")
        sleep(1)

        // Step 2 — schedule defaults are valid; pick a location via search
        // (selecting a result opens the confirmation sheet).
        tapElement(app.staticTexts["Pilih Lokasi"], "location picker")
        let searchTrigger = app.staticTexts["Cari lokasi event"]
        XCTAssertTrue(searchTrigger.waitForExistence(timeout: 15), "map search missing")
        sleep(1)
        searchTrigger.tap()

        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 10), "search field missing")
        searchField.tap()
        app.typeText("Monas Jakarta")
        // Geocoding normalizes the query ("Monas" → "Monumen Nasional"), so
        // select the first result row instead of matching a substring.
        let rows = app.collectionViews.firstMatch.buttons
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 25), "search result missing")
        rows.firstMatch.tap()
        sleep(2) // modal dismisses, then the confirmation sheet presents

        let confirmLocation = app.staticTexts["Gunakan Lokasi Ini"]
        XCTAssertTrue(confirmLocation.waitForExistence(timeout: 15), "location confirm missing")
        confirmLocation.tap()
        sleep(1)

        app.swipeUp()
        tapLabeled(app, "Lanjut")
        sleep(1)

        // Step 3 — criteria chip; capacity 10 kg and per-donor limit 1 kg
        // are the form defaults.
        tapElement(app.buttons["Katun"], "criteria chip")

        let submit = app.buttons["Buat Acara"]
        XCTAssertTrue(submit.waitForExistence(timeout: 10), "submit missing")
        submit.tap()

        let success = app.staticTexts["Acara berhasil Dibuat !"]
        XCTAssertTrue(success.waitForExistence(timeout: 60), "draft creation did not reach success view")

        // "Lihat Halaman Acara" closes the flow and lands on the detail; go
        // back to the dashboard.
        tapLabeled(app, "Lihat Halaman Acara")
        backToDashboard(app)
        XCTAssertTrue(
            app.staticTexts[eventName].waitForExistence(timeout: 30),
            "created draft missing from dashboard list"
        )

        // Relaunch — the draft must survive (offline queue flush + cache).
        app.terminate()
        app.launch()
        loginIfNeeded(app)
        XCTAssertTrue(
            app.staticTexts[eventName].waitForExistence(timeout: 30),
            "draft did not survive relaunch"
        )

        // Edit the name through the detail screen.
        tapElement(app.staticTexts[eventName], "draft card")
        tapLabeled(app, "Edit Acara")
        let nameRow = app.staticTexts[eventName]
        XCTAssertTrue(nameRow.waitForExistence(timeout: 15), "edit info row missing")
        sleep(1)
        nameRow.tap()

        let editorField = app.textFields["Nama Acara"]
        XCTAssertTrue(editorField.waitForExistence(timeout: 15), "general info editor missing")
        editorField.tap()
        editorField.typeText(
            String(repeating: XCUIKeyboardKey.delete.rawValue, count: eventName.count) + editedName
        )
        let save = app.buttons["editEventSave"]
        XCTAssertTrue(save.waitForExistence(timeout: 5), "editor save missing")
        save.tap()
        sleep(1)

        // The edit goes through DashboardModel.createDraft (same id = upsert).
        app.terminate()
        app.launch()
        loginIfNeeded(app)
        XCTAssertTrue(
            app.staticTexts[editedName].waitForExistence(timeout: 30),
            "edited name missing after relaunch"
        )

        // Delete the draft: detail → edit → delete → swipe-to-confirm.
        tapElement(app.staticTexts[editedName], "edited draft card")
        tapLabeled(app, "Edit Acara")
        tapElement(app.buttons["Hapus Acara"], "delete button")

        let swipeTrack = app.staticTexts["Hapus Acara"]
        XCTAssertTrue(swipeTrack.waitForExistence(timeout: 15), "confirmation sheet missing")
        sleep(1)
        let start = swipeTrack.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.5))
        let end = swipeTrack.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
        start.press(forDuration: 0.2, thenDragTo: end)

        tapLabeled(app, "Kembali ke Beranda")

        app.terminate()
        app.launch()
        loginIfNeeded(app)
        // Wait past the first list load before asserting absence.
        _ = app.staticTexts[editedName].waitForExistence(timeout: 20)
        XCTAssertFalse(
            app.staticTexts[editedName].exists,
            "deleted draft still listed after relaunch"
        )
    }

    // MARK: - Helpers

    @MainActor
    private func tapElement(_ element: XCUIElement, _ name: String) {
        guard element.waitForExistence(timeout: 15) else {
            XCTFail("\(name) missing")
            return
        }
        // A tap right after a transition can race the layout; settling
        // briefly and letting the query re-resolve keeps this deterministic.
        sleep(1)
        if element.isHittable {
            element.tap()
        } else {
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }

    @MainActor
    private func tapLabeled(_ app: XCUIApplication, _ label: String) {
        let button = app.buttons[label]
        if button.waitForExistence(timeout: 15) {
            sleep(1)
            if !button.isHittable {
                app.swipeUp()
            }
            button.tap()
            return
        }
        tapElement(app.staticTexts[label], label)
    }

    @MainActor
    private func loginIfNeeded(_ app: XCUIApplication) {
        let emailField = app.textFields["Masukkan email"]
        guard emailField.waitForExistence(timeout: 10) else {
            return // already signed in
        }
        emailField.tap()
        emailField.typeText(email)

        let passwordField = app.secureTextFields["Masukkan password"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 5))
        passwordField.tap()
        passwordField.typeText(password)

        let signIn = app.buttons["Masuk"]
        XCTAssertTrue(signIn.waitForExistence(timeout: 5))
        signIn.tap()

        let ready = app.buttons["Mulai Membuat Event"]
            .waitForExistence(timeout: 30)
            || app.staticTexts["Rekap Donasi"].waitForExistence(timeout: 30)
        XCTAssertTrue(ready, "dashboard did not appear after sign-in")
        // The Sign-in-with-Apple remote scene (SafariViewService) churns
        // through a foreground-focal state right after sign-in and swallows
        // synthetic taps fired during that window; let it settle.
        sleep(3)
    }

    @MainActor
    private func openCreateFlow(_ app: XCUIApplication) {
        let emptyState = app.buttons["Mulai Membuat Event"]
        if emptyState.waitForExistence(timeout: 5) {
            emptyState.tap()
            return
        }
        let add = app.buttons["dashboardAddEvent"]
        XCTAssertTrue(add.waitForExistence(timeout: 15), "create entry point missing")
        add.tap()
    }

    @MainActor
    private func backToDashboard(_ app: XCUIApplication) {
        // EventDetailView's back button is unlabeled; the dashboard root is
        // recognized by its recap header.
        let recap = app.staticTexts["Rekap Donasi"]
        var attempts = 0
        while !recap.exists, attempts < 3 {
            app.buttons.element(boundBy: 0).tap()
            attempts += 1
            _ = recap.waitForExistence(timeout: 5)
        }
        XCTAssertTrue(recap.exists, "dashboard not reached from detail")
    }
}
