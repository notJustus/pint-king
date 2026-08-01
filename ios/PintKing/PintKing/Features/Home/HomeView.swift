//
//  HomeView.swift
//  PintKing
//
//  The Home tab: the group switcher (Task 8) over a Leaderboard/Map segmented
//  control (Tasks 9 and 24). When the user belongs to no group there's nothing
//  to rank or plot, so the switcher's empty state ("Join or create a group…")
//  takes the whole screen; once a group is active the switcher collapses into
//  the nav-bar title and the selected section fills the content. The branch
//  reads the Active_Group live from the repository — shared state with a single
//  owner (l3-ios-app.md §1) — so create/join/leave/switch elsewhere re-render
//  this for free.
//
//  Which section is showing is one enum of pure view state with no rules
//  attached, so it stays here as `@State` rather than earning a view model.
//

import SwiftUI

struct HomeView: View {
    private let groupRepository: any GroupRepositoryProtocol
    private let leaderboardRepository: any LeaderboardRepositoryProtocol
    private let pintRepository: any PintRepositoryProtocol
    private let mapRepository: any MapRepositoryProtocol

    @State private var section: HomeSection = .leaderboard

    init(
        groupRepository: any GroupRepositoryProtocol,
        leaderboardRepository: any LeaderboardRepositoryProtocol,
        pintRepository: any PintRepositoryProtocol,
        mapRepository: any MapRepositoryProtocol
    ) {
        self.groupRepository = groupRepository
        self.leaderboardRepository = leaderboardRepository
        self.pintRepository = pintRepository
        self.mapRepository = mapRepository
    }

    var body: some View {
        NavigationStack {
            if groupRepository.activeGroup == nil {
                // No active group: the switcher's full empty state prompts create/join.
                GroupSwitcherView(groupRepository: groupRepository)
                    .navigationTitle("Home")
                    .navigationBarTitleDisplayMode(.inline)
            } else {
                VStack(spacing: 0) {
                    sectionPicker

                    switch section {
                    case .leaderboard:
                        LeaderboardView(
                            groupRepository: groupRepository,
                            leaderboardRepository: leaderboardRepository,
                            pintRepository: pintRepository
                        )
                    case .map:
                        MapContentView(
                            groupRepository: groupRepository,
                            mapRepository: mapRepository
                        )
                    }
                }
                .toolbar {
                    // The switcher collapses to a compact menu in the title slot.
                    ToolbarItem(placement: .principal) {
                        GroupSwitcherView(groupRepository: groupRepository)
                    }
                }
            }
        }
    }

    private var sectionPicker: some View {
        Picker("Section", selection: $section) {
            ForEach(HomeSection.allCases, id: \.self) { section in
                Text(section.title).tag(section)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

/// The two things the Home tab can show for the Active_Group.
private enum HomeSection: CaseIterable {
    case leaderboard
    case map

    var title: String {
        switch self {
        case .leaderboard: "Leaderboard"
        case .map: "Map"
        }
    }
}

#Preview("With groups") {
    HomeView(
        groupRepository: MockGroupRepository(),
        leaderboardRepository: MockLeaderboardRepository(),
        pintRepository: MockPintRepository(),
        mapRepository: MockMapRepository()
    )
}

#Preview("No groups") {
    HomeView(
        groupRepository: MockGroupRepository(groups: [], activeGroupId: nil),
        leaderboardRepository: MockLeaderboardRepository(),
        pintRepository: MockPintRepository(),
        mapRepository: MockMapRepository()
    )
}
