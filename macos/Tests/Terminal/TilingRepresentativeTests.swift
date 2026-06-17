import Testing
@testable import Ghostty

@Suite
struct TilingRepresentativeTests {
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
