import Foundation

/// What a tap on the map may do right now. Kept free of SwiftUI so the
/// precedence between dismissing the keyboard and explaining a lock is a
/// plain function that tests can pin down.
enum MapTapAction: Equatable {
    case resignSearch
    case hintWalkingPreviewLocked
    case hintRunLocked
    case selectPin
}

enum MapTapPolicy {
    static func action(
        isSearchEditing: Bool,
        walkingLocksDestination: Bool,
        runLocksRouteInput: Bool
    ) -> MapTapAction {
        if isSearchEditing { return .resignSearch }
        if walkingLocksDestination { return .hintWalkingPreviewLocked }
        if runLocksRouteInput { return .hintRunLocked }
        return .selectPin
    }
}
