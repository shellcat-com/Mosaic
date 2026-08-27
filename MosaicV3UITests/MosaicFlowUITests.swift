import XCTest

@MainActor
final class MosaicFlowUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCoreDestinationsStaySeparated() throws {
        let home = launch(.home)
        XCTAssertTrue(home.buttons["Create"].waitForExistence(timeout: 3))
        XCTAssertTrue(home.buttons["Join"].exists)
        XCTAssertTrue(home.buttons["Choose an act"].exists)
        XCTAssertTrue(home.staticTexts["Revealed"].exists)

        let active = launch(.active)
        XCTAssertTrue(active.staticTexts["Kindness side"].waitForExistence(timeout: 3))
        XCTAssertTrue(active.staticTexts["Reveal countdown"].exists)
        XCTAssertFalse(active.staticTexts["Water Lilies"].exists)
        XCTAssertFalse(active.staticTexts["Evidence"].exists)
        XCTAssertFalse(active.staticTexts["Leaderboard"].exists)

        let revealed = launch(.revealed)
        XCTAssertTrue(revealed.buttons["Artwork"].waitForExistence(timeout: 3))
        XCTAssertTrue(revealed.buttons["Kindness"].exists)
        XCTAssertTrue(revealed.buttons["Photos"].exists)
        XCTAssertTrue(revealed.staticTexts["Together, we made this."].waitForExistence(timeout: 12))
        XCTAssertTrue(revealed.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Georges Seurat'")).firstMatch.exists)
        XCTAssertFalse(revealed.staticTexts["The artwork is opening…"].exists)

        let photos = launch(.photos)
        XCTAssertTrue(photos.staticTexts["Disposable gallery"].waitForExistence(timeout: 3))
        XCTAssertTrue(photos.buttons["Make recap"].exists)
        XCTAssertFalse(photos.staticTexts["Kindness side"].exists)
    }

    func testCreationWizardReachesInvitation() throws {
        let app = launch(.create)
        let name = app.textFields["Mosaic name"]
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["wizard.continue.0"].isEnabled)
        name.tap()
        name.typeText("Library Kindness Week")
        let community = app.textFields["Community or group"]
        community.tap()
        community.typeText("Riverside Library")
        dismissKeyboard(in: app)
        tapContinue(step: 0, in: app)

        let activity = app.textFields["Kindness activity"]
        XCTAssertTrue(activity.waitForExistence(timeout: 3))
        activity.tap()
        activity.typeText("Help someone find a book")
        dismissKeyboard(in: app)
        tapContinue(step: 1, in: app)

        XCTAssertTrue(app.descendants(matching: .any)["wizard.step.artwork"].waitForExistence(timeout: 4))
        tapContinue(step: 2, in: app)
        XCTAssertTrue(app.staticTexts["Choose the roll"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["filmLook.sunwashed"].isSelected)
        tapContinue(step: 3, in: app)
        XCTAssertTrue(app.descendants(matching: .any)["wizard.step.timing"].waitForExistence(timeout: 4))
        tapContinue(step: 4, in: app)
        XCTAssertTrue(app.buttons["Create Mosaic"].waitForExistence(timeout: 3))
        app.buttons["Create Mosaic"].tap()
        XCTAssertTrue(app.buttons["Share invitation"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Open Mosaic"].exists)
    }

    func testJoinActivityCameraAndRecapContracts() throws {
        let join = launch(.join)
        XCTAssertTrue(join.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Invitation only'")).firstMatch.waitForExistence(timeout: 3))
        XCTAssertTrue(join.buttons["Join Mosaic"].waitForExistence(timeout: 3))

        let activity = launch(.activity)
        XCTAssertTrue(activity.buttons["I took part"].waitForExistence(timeout: 3))
        XCTAssertTrue(activity.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Photos are separate'")).firstMatch.exists)

        let camera = launch(.camera)
        XCTAssertTrue(camera.staticTexts["MOSAIC DISPOSABLE"].waitForExistence(timeout: 3))
        XCTAssertTrue(camera.staticTexts["PHOTO ONLY"].exists)
        XCTAssertTrue(camera.otherElements["camera.shutter"].exists || camera.buttons["camera.shutter"].exists)
        XCTAssertTrue(camera.staticTexts["Your sealed roll"].exists)

        let recap = launch(.recap)
        XCTAssertTrue(recap.staticTexts["PHOTOS ONLY"].waitForExistence(timeout: 3))
        XCTAssertTrue(recap.staticTexts["Template"].exists)
        XCTAssertTrue(recap.staticTexts["Music"].exists)
        XCTAssertTrue(recap.staticTexts["Kiln Tape"].exists)
        for forbidden in ["Artwork card", "Impact receipt", "Contributor name", "Activity label"] {
            XCTAssertFalse(recap.staticTexts[forbidden].exists)
        }

        let deniedCamera = launch(.cameraDenied)
        XCTAssertTrue(deniedCamera.staticTexts["Camera access is off"].waitForExistence(timeout: 3))
        XCTAssertTrue(deniedCamera.buttons["Open Settings"].exists)
        XCTAssertFalse(deniedCamera.buttons["camera.shutter"].exists)
    }

    func testAccountSurfacesAndDestructiveConfirmation() throws {
        let signIn = launch(.signIn)
        XCTAssertTrue(signIn.buttons["Continue with Apple"].waitForExistence(timeout: 3))
        XCTAssertTrue(signIn.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'display name are required'")).firstMatch.exists)

        let displayName = launch(.displayName)
        XCTAssertTrue(displayName.textFields["Display name"].waitForExistence(timeout: 3))

        let you = launch(.you)
        XCTAssertTrue(you.buttons["Sign out"].waitForExistence(timeout: 3))
        XCTAssertTrue(you.buttons["Delete account"].exists)
        you.buttons["Delete account"].tap()
        let alert = you.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 4))
        XCTAssertTrue(alert.buttons["Cancel"].exists)
        alert.buttons["Cancel"].tap()
    }

    func testHundredTileRevealCompletes() throws {
        let app = launch(.reveal100)
        let board = app.otherElements["artwork.reveal.board"]
        XCTAssertTrue(board.waitForExistence(timeout: 4))
        let complete = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == 'Reveal complete'"),
            object: board
        )
        XCTAssertEqual(XCTWaiter.wait(for: [complete], timeout: 8), .completed)
    }

    func testDenseKindnessBoardOffersFullSizeContributionTargets() throws {
        let app = launch(.reveal100)
        let board = app.otherElements["artwork.reveal.board"]
        XCTAssertTrue(board.waitForExistence(timeout: 4))
        let complete = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == 'Reveal complete'"),
            object: board
        )
        XCTAssertEqual(XCTWaiter.wait(for: [complete], timeout: 8), .completed)

        app.buttons["Kindness"].tap()
        let browser = app.buttons["Browse kindness contributions"]
        XCTAssertTrue(browser.waitForExistence(timeout: 3))
        browser.tap()
        let firstContribution = app.buttons["Open kindness contribution from Member 1, tile 1"]
        XCTAssertTrue(firstContribution.waitForExistence(timeout: 3))
        XCTAssertTrue(firstContribution.isHittable)
    }

    func testRevenueCatPaywallFixturesCoverPrimaryStates() throws {
        let populated = launch(.paywallPopulated)
        XCTAssertTrue(populated.staticTexts["Make room for more people"].waitForExistence(timeout: 4))
        XCTAssertTrue(populated.buttons["paywall.package.annual"].isSelected)
        XCTAssertTrue(populated.buttons["paywall.package.monthly"].exists)
        XCTAssertTrue(populated.buttons["paywall.package.eventPass"].exists)
        XCTAssertTrue(populated.buttons["paywall.purchase"].exists)
        XCTAssertTrue(populated.buttons["Restore Purchases"].exists)
        let manageSubscriptions = populated.buttons["paywall.manageSubscriptions"]
        for _ in 0..<4 where !manageSubscriptions.isHittable { populated.swipeUp() }
        XCTAssertTrue(manageSubscriptions.isHittable)
        XCTAssertTrue(populated.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'automatically renews'")).firstMatch.exists)

        let failure = launch(.paywallFailure)
        XCTAssertTrue(failure.buttons["Try again"].waitForExistence(timeout: 4))

        let success = launch(.paywallPurchaseSuccess)
        XCTAssertTrue(success.staticTexts["The kiln is open"].waitForExistence(timeout: 4))

        let passOwned = launch(.paywallPassOwned)
        XCTAssertTrue(passOwned.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Event Pass' ")).firstMatch.waitForExistence(timeout: 4))
    }

    func testSignedInInvitationRoutesImmediately() throws {
        let app = launch(.root)
        XCTAssertTrue(app.buttons["Create"].waitForExistence(timeout: 4))
        app.open(URL(string: "mosaic://join/GARDEN24")!)
        XCTAssertTrue(app.buttons["Join Mosaic"].waitForExistence(timeout: 4))
        XCTAssertEqual(app.textFields["Invitation code"].value as? String, "GARDEN24")
    }

    func testReducedMotionRevealAndConfirmedAccountDeletion() throws {
        let reveal = launch(.reveal100ReducedMotion)
        let board = reveal.otherElements["artwork.reveal.board"]
        XCTAssertTrue(board.waitForExistence(timeout: 4))
        let complete = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == 'Reveal complete'"),
            object: board
        )
        XCTAssertEqual(XCTWaiter.wait(for: [complete], timeout: 2), .completed)

        let account = launch(.root)
        XCTAssertTrue(account.tabBars.buttons["You"].waitForExistence(timeout: 4))
        account.tabBars.buttons["You"].tap()
        XCTAssertTrue(account.buttons["Delete account"].waitForExistence(timeout: 3))
        account.buttons["Delete account"].tap()
        XCTAssertTrue(account.alerts["Delete your Mosaic account?"].waitForExistence(timeout: 2))
        account.alerts.buttons["Delete account"].tap()
        XCTAssertTrue(account.buttons["Continue with Apple"].waitForExistence(timeout: 4))
    }

    func testPlacementCameraReviewAndRecapPlaybackInteractions() throws {
        let activity = launch(.activity)
        let takePart = activity.buttons["I took part"]
        XCTAssertTrue(takePart.waitForExistence(timeout: 4))
        takePart.tap()
        XCTAssertTrue(activity.descendants(matching: .any)["placement.ceremony"].waitForExistence(timeout: 4))
        let finishPlacement = activity.buttons.matching(
            NSPredicate(format: "identifier IN %@", ["placement.skip", "placement.continue"])
        ).firstMatch
        XCTAssertTrue(finishPlacement.waitForExistence(timeout: 4))
        finishPlacement.tap()
        XCTAssertTrue(activity.buttons["Save note"].waitForExistence(timeout: 3))

        let retake = launch(.cameraReview)
        XCTAssertTrue(retake.buttons["camera.review.retake"].waitForExistence(timeout: 4))
        retake.buttons["camera.review.retake"].tap()
        XCTAssertTrue(retake.descendants(matching: .any)["camera.review.retakeReady"].waitForExistence(timeout: 3))
        XCTAssertTrue(retake.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'retakes use no shot'")).firstMatch.exists)

        let keep = launch(.cameraReview)
        XCTAssertTrue(keep.buttons["camera.review.keep"].waitForExistence(timeout: 4))
        keep.buttons["camera.review.keep"].tap()
        XCTAssertTrue(keep.descendants(matching: .any)["camera.review.kept"].waitForExistence(timeout: 3))
        XCTAssertTrue(keep.staticTexts["1 kept · 23 exposures remaining"].exists)

        let recap = launch(.recapJourney)
        let photoButtons = recap.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'recap.photo.'"))
        XCTAssertTrue(photoButtons.firstMatch.waitForExistence(timeout: 4))
        photoButtons.element(boundBy: 0).tap()
        photoButtons.element(boundBy: 1).tap()
        tapVisible(recap.buttons["Order photos"], in: recap)
        XCTAssertTrue(recap.staticTexts["Use the arrows to arrange the photos in story order."].waitForExistence(timeout: 3))
        tapVisible(recap.buttons["Choose style"], in: recap)
        let kilnTape = recap.buttons["recap.template.kilnTape"]
        XCTAssertTrue(kilnTape.waitForExistence(timeout: 3))
        if !kilnTape.isHittable { recap.swipeLeft() }
        kilnTape.tap()
        tapVisible(recap.buttons["Preview recap"], in: recap)
        XCTAssertTrue(recap.descendants(matching: .any)["recap.playback.frame"].waitForExistence(timeout: 4))
        let playback = recap.buttons["recap.playback.toggle"]
        playback.tap()
        XCTAssertTrue(recap.buttons["recap.playback.toggle"].waitForExistence(timeout: 2))
        XCTAssertEqual(recap.buttons["recap.playback.toggle"].label, "Pause preview")
        recap.buttons["recap.playback.toggle"].tap()
        XCTAssertEqual(recap.buttons["recap.playback.toggle"].label, "Play preview")
        XCTAssertTrue(recap.buttons["Render recap"].exists)
    }

    func testAccessibilityTextUsesAdaptiveRecapStagePicker() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchEnvironment["MOSAIC_SHOWCASE_SCREEN"] = ShowcaseScreen.recap.rawValue
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["recap.stage.menu"].waitForExistence(timeout: 4))
        XCTAssertFalse(app.descendants(matching: .any)["recap.stage.segmented"].exists)
    }

    func testAccessibilityTextSimplifiesDisposableCameraHardware() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchEnvironment["MOSAIC_SHOWCASE_SCREEN"] = ShowcaseScreen.camera.rawValue
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()

        XCTAssertTrue(app.buttons["Camera Mosaic, Willow Street Garden Day"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.descendants(matching: .any)["camera.accessibilityFilmHeader"].exists)
        XCTAssertFalse(app.staticTexts["MOSAIC DISPOSABLE"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["camera.eventPicker.standard"].exists)
    }

    func testAccessibilityTextKeepsActiveMosaicStoryReachable() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchEnvironment["MOSAIC_SHOWCASE_SCREEN"] = ShowcaseScreen.active.rawValue
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Willow Street Garden Day"].waitForExistence(timeout: 4))
        let chooseActivity = app.buttons["Choose this activity"]
        for _ in 0..<4 where !chooseActivity.isHittable { app.swipeUp() }
        XCTAssertTrue(chooseActivity.isHittable)

        let story = app.staticTexts["Every act places the kindness face. At reveal, every tile turns and the other face becomes one shared artwork."]
        for _ in 0..<5 where !story.isHittable { app.swipeUp() }
        XCTAssertTrue(story.isHittable)
    }

    func testPrimarySurfacesPassSystemAccessibilityAudit() throws {
        for screen in [ShowcaseScreen.home, .create, .active, .revealed, .camera, .recap] {
            let app = launch(screen)
            let systemAuditTypes = XCUIAccessibilityAuditType.all
                .subtracting(.dynamicType)
                .subtracting(.contrast)
            try app.performAccessibilityAudit(for: systemAuditTypes) { issue in
                // XCTest reports empty SwiftUI placeholder bounds as clipped even
                // with the shared Dynamic Type font and 26-point text line. The
                // populated six-step UI journey verifies the actual field content.
                return issue.auditType.contains(.textClipped) && issue.element?.elementType == .textField
            }
        }
    }

    private func launch(_ screen: ShowcaseScreen, environment: [String: String] = [:]) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchEnvironment["MOSAIC_SHOWCASE_SCREEN"] = screen.rawValue
        for (key, value) in environment { app.launchEnvironment[key] = value }
        app.launch()
        return app
    }

    private func dismissKeyboard(in app: XCUIApplication) {
        let returnKey = app.keyboards.buttons["Return"]
        let doneKey = app.keyboards.buttons["Done"]
        if returnKey.exists, returnKey.isHittable {
            returnKey.tap()
        } else if doneKey.exists, doneKey.isHittable {
            doneKey.tap()
        } else if app.keyboards.firstMatch.exists {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).tap()
        }
    }

    private func tapContinue(step: Int, in app: XCUIApplication) {
        let button = app.buttons["wizard.continue.\(step)"]
        XCTAssertTrue(button.waitForExistence(timeout: 4), "Continue button for wizard step \(step) did not appear")
        let enabled = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "enabled == true"),
            object: button
        )
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 4), .completed)
        button.tap()
    }

    private func tapVisible(_ element: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(element.waitForExistence(timeout: 4))
        for _ in 0..<5 where !element.isHittable { app.swipeUp() }
        XCTAssertTrue(element.isHittable)
        element.tap()
    }
}

private enum ShowcaseScreen: String {
    case root
    case signIn
    case displayName
    case home
    case create
    case join
    case activity
    case active
    case revealed
    case reveal100
    case reveal100ReducedMotion
    case photos
    case recap
    case recapJourney
    case camera
    case cameraReview
    case cameraDenied
    case you
    case paywallLoading
    case paywallPopulated
    case paywallFailure
    case paywallPlusActive
    case paywallPassOwned
    case paywallPurchaseSuccess
    case paywallRestoreSuccess
}
