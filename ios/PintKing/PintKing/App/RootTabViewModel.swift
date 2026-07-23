//
//  RootTabViewModel.swift
//  PintKing
//
//  Drives the 3-tab shell (Home / "+" / Profile). The "+" tab is a *trigger*,
//  not a destination: selecting it presents the camera as a full-screen modal
//  and leaves the visible tab where it was, so dismissing the modal returns
//  there (l3-ios-app.md §2). "+" is a no-op when the user has no active group —
//  the button is greyed out, not hidden.
//

import Foundation

/// The three items in the bottom bar. `add` is a pseudo-tab: it never becomes
/// the selected content, it just opens the camera.
enum RootTab: Hashable {
    case home
    case add
    case profile
}

@MainActor
@Observable
final class RootTabViewModel {
    /// The tab whose content is currently shown. Never `.add`.
    private(set) var selectedTab: RootTab = .home

    /// Whether the camera modal is on screen. The modal's close button sets this
    /// back to false, which returns the user to `selectedTab`.
    var isCameraPresented = false

    private let groupRepository: any GroupRepositoryProtocol

    init(groupRepository: any GroupRepositoryProtocol) {
        self.groupRepository = groupRepository
    }

    /// True when there's an active group to log a pint into. The "+" button is
    /// disabled (greyed out) when this is false.
    var canLogPint: Bool {
        groupRepository.activeGroup != nil
    }

    /// Handle a tab tap. `.add` opens the camera (if allowed) without changing
    /// the visible tab; the other cases just switch content.
    func select(_ tab: RootTab) {
        switch tab {
        case .add:
            guard canLogPint else { return }
            isCameraPresented = true
        case .home, .profile:
            selectedTab = tab
        }
    }
}
