import AppKit
import Testing
@testable import Ghostty

@Suite
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

    @Test
    func hiddenSameIdentifierSiblingDoesNotSuppressLaunchWindow() {
        #expect(TilingState.isDragDetachSibling(
            sharesTabbingIdentifier: true,
            isVisible: false
        ) == false)
    }

    @Test
    func visibleSameIdentifierSiblingSuppressesDragDetachedWindow() {
        #expect(TilingState.isDragDetachSibling(
            sharesTabbingIdentifier: true,
            isVisible: true
        ) == true)
    }
}
