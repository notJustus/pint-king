//
//  LeaderboardView.swift
//  PintKing
//
//  The leaderboard on the Home tab: a period filter, the ranked list of active
//  members (crown on rank 1, movement delta for bounded periods), and a greyed
//  "Former Members" section (Property 23). A thin renderer over
//  LeaderboardViewModel — every decision (the split, delta visibility, the crown)
//  lives there so it can be unit-tested without SwiftUI.
//
//  Avatars are initials placeholders for now: leaderboard rows carry an
//  `avatarUrl` path, but loading remote images needs the networking layer, so
//  real avatars land with Task 26.
//

import SwiftUI

struct LeaderboardView: View {
    @State private var model: LeaderboardViewModel

    /// Held so the row → Member Pint History navigation can build the destination
    /// screen. The leaderboard reads the active group live; the history screen
    /// does the same, so only the tapped member (id + name) needs threading.
    private let groupRepository: any GroupRepositoryProtocol
    private let pintRepository: any PintRepositoryProtocol

    init(
        groupRepository: any GroupRepositoryProtocol,
        leaderboardRepository: any LeaderboardRepositoryProtocol,
        pintRepository: any PintRepositoryProtocol
    ) {
        self.groupRepository = groupRepository
        self.pintRepository = pintRepository
        _model = State(initialValue: LeaderboardViewModel(
            groupRepository: groupRepository,
            leaderboardRepository: leaderboardRepository
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            periodPicker

            if model.isLoading && !model.hasEntries {
                skeletonList
            } else if !model.hasEntries {
                emptyState
            } else {
                leaderboardList
            }
        }
        .task { await model.load() }
    }

    // MARK: - Period filter

    private var periodPicker: some View {
        Picker("Period", selection: periodBinding) {
            Text("All-Time").tag(Period.allTime)
            Text("This Week").tag(Period.thisWeek)
            Text("This Month").tag(Period.thisMonth)
        }
        .pickerStyle(.segmented)
        .padding()
    }

    /// Forwards a segment tap to the view model, which re-fetches. The getter
    /// reflects the model so the control stays in sync if the period is set elsewhere.
    private var periodBinding: Binding<Period> {
        Binding(
            get: { model.selectedPeriod },
            set: { period in Task { await model.select(period) } }
        )
    }

    // MARK: - List

    private var leaderboardList: some View {
        List {
            Section {
                ForEach(model.activeMembers) { entry in
                    memberLink(entry) {
                        LeaderboardRow(entry: entry,
                                       crowned: model.isCrowned(entry),
                                       showsDelta: model.showsRankDelta)
                    }
                }
            }

            if model.hasFormerMembers {
                Section("Former Members") {
                    ForEach(model.formerMembers) { entry in
                        memberLink(entry) {
                            LeaderboardRow(entry: entry, crowned: false, showsDelta: false)
                                .foregroundStyle(.secondary)   // greyed out
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .refreshable { await model.refresh() }
        .navigationDestination(for: MemberRoute.self) { route in
            MemberPintHistoryView(
                userId: route.userId,
                memberName: route.name,
                groupRepository: groupRepository,
                pintRepository: pintRepository
            )
        }
    }

    /// Wraps a row in a `NavigationLink` to that member's pint history. The whole
    /// row is the tap target; a lightweight `MemberRoute` (just the id + name the
    /// destination needs) is the navigation value, keeping the route decoupled
    /// from the leaderboard DTO.
    private func memberLink<Content: View>(
        _ entry: LeaderboardEntry,
        @ViewBuilder label: () -> Content
    ) -> some View {
        NavigationLink(value: MemberRoute(userId: entry.userId, name: entry.displayName),
                       label: label)
    }

    // MARK: - Empty & loading states

    private var emptyState: some View {
        ContentUnavailableView(
            "No pints logged yet",
            systemImage: "mug",
            description: Text("Be the first to log a pint in this group.")
        )
    }

    private var skeletonList: some View {
        List(0..<6, id: \.self) { _ in
            SkeletonRow()
        }
        .listStyle(.plain)
        .disabled(true)
    }
}

/// The navigation value for a leaderboard row → Member Pint History. Only the
/// tapped member's id (fetch key) and name (title) need threading — the history
/// screen reads the active group live, just like the leaderboard.
private struct MemberRoute: Hashable {
    let userId: UUID
    let name: String
}

// MARK: - Row

/// One leaderboard row: rank (crown on 1), initials avatar, name, optional delta,
/// pint count. Former-member styling (grey) is applied by the caller.
private struct LeaderboardRow: View {
    let entry: LeaderboardEntry
    let crowned: Bool
    let showsDelta: Bool

    var body: some View {
        HStack(spacing: 12) {
            rankBadge
            AvatarCircle(name: entry.displayName)
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayName)
                    .font(.body.weight(.medium))
                if showsDelta, let delta = entry.rankDelta {
                    RankDeltaLabel(delta: delta)
                }
            }

            Spacer()

            Text("\(entry.pintCount)")
                .font(.headline.monospacedDigit())
        }
        .padding(.vertical, 4)
    }

    /// The rank number, or a crown for rank 1. Former members (rank 0) show nothing.
    @ViewBuilder private var rankBadge: some View {
        if crowned {
            Image(systemName: "crown.fill")
                .foregroundStyle(.yellow)
                .frame(width: 28)
        } else if entry.rank > 0 {
            Text("\(entry.rank)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 28)
        } else {
            Color.clear.frame(width: 28)
        }
    }
}

/// Movement since the prior period: green up-arrow for a climb, red down-arrow
/// for a drop, dash for no change.
private struct RankDeltaLabel: View {
    let delta: Int

    var body: some View {
        Label {
            Text("\(abs(delta))")
        } icon: {
            Image(systemName: symbol)
        }
        .font(.caption)
        .foregroundStyle(colour)
        .labelStyle(.titleAndIcon)
    }

    // A positive delta means the member moved *up* the board (rank got smaller).
    private var symbol: String {
        if delta > 0 { "arrow.up" } else if delta < 0 { "arrow.down" } else { "minus" }
    }
    private var colour: Color {
        if delta > 0 { .green } else if delta < 0 { .red } else { .secondary }
    }
}

/// Circular initials placeholder (real avatars arrive with networking, Task 26).
private struct AvatarCircle: View {
    let name: String

    var body: some View {
        ZStack {
            Circle().fill(.tint.opacity(0.2))
            Text(InitialsGenerator.initials(from: name))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tint)
        }
    }
}

/// A single placeholder row shown while the first load is in flight.
private struct SkeletonRow: View {
    var body: some View {
        HStack(spacing: 12) {
            Circle().fill(.quaternary).frame(width: 40, height: 40)
            RoundedRectangle(cornerRadius: 4).fill(.quaternary).frame(height: 14)
            Spacer()
            RoundedRectangle(cornerRadius: 4).fill(.quaternary).frame(width: 24, height: 14)
        }
        .padding(.vertical, 8)
        .redacted(reason: .placeholder)
    }
}

#Preview("Populated") {
    NavigationStack {
        LeaderboardView(
            groupRepository: MockGroupRepository(),
            leaderboardRepository: MockLeaderboardRepository(),
            pintRepository: MockPintRepository()
        )
    }
}

#Preview("Empty") {
    NavigationStack {
        LeaderboardView(
            groupRepository: MockGroupRepository(groups: [], activeGroupId: nil),
            leaderboardRepository: MockLeaderboardRepository(),
            pintRepository: MockPintRepository()
        )
    }
}
