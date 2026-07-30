//
//  HomeView.swift
//  PintKing
//
//  The Home tab: the group switcher (Task 8) plus the leaderboard (Task 9). When
//  the user belongs to no group there's nothing to rank, so the switcher's empty
//  state ("Join or create a group…") takes the whole screen; once a group is
//  active the switcher collapses into the nav-bar title and the leaderboard fills
//  the content. The branch reads the Active_Group live from the repository —
//  shared state with a single owner (l3-ios-app.md §1) — so create/join/leave/
//  switch elsewhere re-render this for free.
//

import SwiftUI

struct HomeView: View {
    private let groupRepository: any GroupRepositoryProtocol
    private let leaderboardRepository: any LeaderboardRepositoryProtocol
    private let pintRepository: any PintRepositoryProtocol

    init(
        groupRepository: any GroupRepositoryProtocol,
        leaderboardRepository: any LeaderboardRepositoryProtocol,
        pintRepository: any PintRepositoryProtocol
    ) {
        self.groupRepository = groupRepository
        self.leaderboardRepository = leaderboardRepository
        self.pintRepository = pintRepository
    }

    var body: some View {
        NavigationStack {
            if groupRepository.activeGroup == nil {
                // No active group: the switcher's full empty state prompts create/join.
                GroupSwitcherView(groupRepository: groupRepository)
                    .navigationTitle("Home")
                    .navigationBarTitleDisplayMode(.inline)
            } else {
                LeaderboardView(
                    groupRepository: groupRepository,
                    leaderboardRepository: leaderboardRepository,
                    pintRepository: pintRepository
                )
                .toolbar {
                    // The switcher collapses to a compact menu in the title slot.
                    ToolbarItem(placement: .principal) {
                        GroupSwitcherView(groupRepository: groupRepository)
                    }
                }
            }
        }
    }
}

#Preview("With groups") {
    HomeView(
        groupRepository: MockGroupRepository(),
        leaderboardRepository: MockLeaderboardRepository(),
        pintRepository: MockPintRepository()
    )
}

#Preview("No groups") {
    HomeView(
        groupRepository: MockGroupRepository(groups: [], activeGroupId: nil),
        leaderboardRepository: MockLeaderboardRepository(),
        pintRepository: MockPintRepository()
    )
}
