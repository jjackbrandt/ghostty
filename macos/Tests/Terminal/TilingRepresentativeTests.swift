import AppKit
import Testing
@testable import Ghostty
import GhosttyKit

@Suite(.serialized)
struct TilingRepresentativeTests {
    @Test @MainActor
    func newTabDeferredPresentationPreservesExistingTabGroupFrame() async throws {
        let config = try TemporaryConfig("""
        initial-window = false
        window-position-x = 24
        window-position-y = 36
        """)
        let ghostty = Ghostty.App(configPath: config.temporaryFile.path())
        try #require(ghostty.readiness == .ready)

        let parentController = TerminalController(ghostty)
        let parentWindow = try #require(parentController.window)
        defer { parentWindow.orderOut(nil) }

        parentController.showWindow(nil)
        let visibleFrame = try #require(parentWindow.screen?.visibleFrame)
        let tileFrame = NSRect(
            x: visibleFrame.midX,
            y: visibleFrame.minY,
            width: visibleFrame.width / 2,
            height: visibleFrame.height
        )
        parentWindow.setFrame(tileFrame, display: false)

        let childController = try #require(TerminalController.newTab(
            ghostty,
            from: parentWindow
        ))
        let childWindow = try #require(childController.window)
        defer { childWindow.orderOut(nil) }

        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                continuation.resume()
            }
        }

        #expect(parentWindow.tabGroup?.windows.count == 2)
        #expect(childWindow.tabGroup === parentWindow.tabGroup)
        #expect(parentWindow.frame == tileFrame)
    }

    @Test @MainActor
    func visibleStandaloneWindowsRemainRepresentatives() async throws {
        try await withTilingFeature(enabled: true) {
            let first = makeWindow(tabbingIdentifier: "terminal")
            let second = makeWindow(tabbingIdentifier: "terminal")
            defer {
                first.close()
                second.close()
            }

            first.orderFront(nil)
            second.orderFront(nil)

            #expect(first.isVisible)
            #expect(second.isVisible)
            #expect(first.tabGroup !== second.tabGroup)
            #expect(first.accessibilityRole() == .window)
            #expect(second.accessibilityRole() == .window)
        }
    }

    @Test @MainActor
    func windowDetachedFromTabGroupRemainsSuppressed() async throws {
        try await withTilingFeature(enabled: true) {
            let representative = makeWindow(tabbingIdentifier: "representative")
            let detached = makeWindow(tabbingIdentifier: "detached")
            defer {
                representative.close()
                detached.close()
            }

            representative.orderFront(nil)
            detached.orderFront(nil)
            representative.addTabbedWindow(detached, ordered: .above)
            let originalGroup = try #require(representative.tabGroup)
            originalGroup.selectedWindow = representative

            #expect(detached.accessibilityRole() == .unknown)

            originalGroup.removeWindow(detached)

            #expect(detached.tabGroup !== originalGroup)
            #expect(detached.accessibilityRole() == .unknown)
            #expect(representative.accessibilityRole() == .window)
        }
    }

    @Test @MainActor
    func disabledFeatureDoesNotHandoffRepresentativeOnClose() async throws {
        try await withTilingFeature(enabled: false) {
            let representative = makeWindow(tabbingIdentifier: "terminal")
            let successor = makeWindow(tabbingIdentifier: "terminal")
            defer { successor.close() }

            representative.addTabbedWindow(successor, ordered: .above)
            let group = try #require(representative.tabGroup)
            group.selectedWindow = representative
            TilingState.repByGroup.setObject(representative, forKey: group)

            representative.close()
            await nextMainQueueTurn()

            #expect(TilingState.repByGroup.object(forKey: group) === representative)
        }
    }

    @Test @MainActor
    func enabledFeatureHandoffsRepresentativeOnClose() async throws {
        try await withTilingFeature(enabled: true) {
            let representative = makeWindow(tabbingIdentifier: "terminal")
            let successor = makeWindow(tabbingIdentifier: "terminal")
            defer { successor.close() }

            representative.addTabbedWindow(successor, ordered: .above)
            let group = try #require(representative.tabGroup)
            group.selectedWindow = representative
            TilingState.repByGroup.setObject(representative, forKey: group)

            representative.close()
            await nextMainQueueTurn()

            #expect(TilingState.repByGroup.object(forKey: group) === successor)
        }
    }

    @MainActor
    private func makeWindow(tabbingIdentifier: String) -> TerminalWindow {
        let window = TerminalWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.tabbingIdentifier = tabbingIdentifier
        return window
    }

    @MainActor
    private func withTilingFeature(
        enabled: Bool,
        _ body: () async throws -> Void
    ) async throws {
        let appDelegate = try #require(NSApp.delegate as? AppDelegate)
        let originalPointer = try #require(appDelegate.ghostty.config.config)
        let originalConfig = try #require(ghostty_config_clone(originalPointer))
        defer {
            appDelegate.ghostty.config.clone(config: originalConfig)
            TilingState.repByGroup.removeAllObjects()
        }

        let testConfig = try TemporaryConfig(
            "macos-window-tabs-tiling-friendly = \(enabled)"
        )
        let testPointer = try #require(testConfig.config)
        let clonedTestConfig = try #require(ghostty_config_clone(testPointer))
        appDelegate.ghostty.config.clone(config: clonedTestConfig)
        TilingState.repByGroup.removeAllObjects()

        try await body()
    }

    @MainActor
    private func nextMainQueueTurn() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                continuation.resume()
            }
        }
    }
}
