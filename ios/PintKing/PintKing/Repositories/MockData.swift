//
//  MockData.swift
//  PintKing
//
//  A single, shared set of hardcoded fixtures used by every Mock*Repository so
//  that IDs line up across domains (a leaderboard entry's `userId` matches a
//  group member's `userId` matches a pint's `userId`). Created once as static
//  lets; every mock reads from these constants and keeps its own mutable copy
//  of anything it lets the app change (active group, member list, pint store).
//
//  These fixtures are the domain models from Task 2 — no separate mock types.
//  Counts here are illustrative and are NOT derived from one another (the mock
//  leaderboards are curated arrays, independent of the mock pint store), exactly
//  as a real backend computes the leaderboard server-side rather than from the
//  pints the client happens to hold.
//

import Foundation

enum MockData {

    // MARK: - Stable identities
    //
    // IDs are generated once at launch. Nothing depends on their literal value;
    // everything references these constants by name, so the graph stays
    // internally consistent within a run.

    static let daveId = UUID()      // the signed-in user
    static let emmaId = UUID()
    static let liamId = UUID()
    static let oliviaId = UUID()
    static let noahId = UUID()
    static let avaId = UUID()
    static let sophiaId = UUID()
    static let fredId = UUID()      // former member of Friday Club (left; pints remain)

    static let fridayId = UUID()
    static let sundayId = UUID()
    static let officeId = UUID()

    // MARK: - Current user

    /// The authenticated user. `activeGroupId` starts on Friday Club.
    static let currentUser = User(
        id: daveId,
        appleId: "000123.dave.0001",
        displayName: "Dave Smith",
        avatarUrl: "avatars/\(daveId)/1.jpg",
        activeGroupId: fridayId
    )

    // MARK: - Groups

    static let friday = Group(
        id: fridayId,
        name: "Friday Club",
        inviteCode: "aB3dE6fH",
        createdBy: daveId,
        createdAt: date(daysAgo: 120)
    )

    static let sunday = Group(
        id: sundayId,
        name: "Sunday League",
        inviteCode: "kM9nP2qR",
        createdBy: emmaId,
        createdAt: date(daysAgo: 80)
    )

    static let office = Group(
        id: officeId,
        name: "Office Crew",
        inviteCode: "tU5vW8xZ",
        createdBy: liamId,
        createdAt: date(daysAgo: 40)
    )

    /// The three groups the current user belongs to at launch.
    static let groups = [friday, sunday, office]

    /// A group the current user is NOT yet a member of, resolvable by its invite
    /// code so `joinGroup` has something real to return. Not in `groups`.
    static let joinableInviteCode = "JOIN1234"
    static let joinableGroup = Group(
        id: UUID(),
        name: "The Locals",
        inviteCode: joinableInviteCode,
        createdBy: noahId,
        createdAt: date(daysAgo: 10)
    )

    // MARK: - Members (denormalised with display name + avatar)

    static func members(of groupId: UUID) -> [GroupMember] {
        switch groupId {
        case fridayId:
            return [
                member(daveId, fridayId, .admin, "Dave Smith", joinedDaysAgo: 120),
                member(emmaId, fridayId, .member, "Emma Byrne", joinedDaysAgo: 118),
                member(liamId, fridayId, .member, "Liam O'Neill", joinedDaysAgo: 100),
                member(oliviaId, fridayId, .member, "Olivia Reed", joinedDaysAgo: 60),
            ]
        case sundayId:
            return [
                member(emmaId, sundayId, .admin, "Emma Byrne", joinedDaysAgo: 80),
                member(daveId, sundayId, .member, "Dave Smith", joinedDaysAgo: 75),
                member(noahId, sundayId, .member, "Noah Patel", joinedDaysAgo: 70),
                member(avaId, sundayId, .member, "Ava Lindqvist", joinedDaysAgo: 30),
            ]
        case officeId:
            return [
                member(liamId, officeId, .admin, "Liam O'Neill", joinedDaysAgo: 40),
                member(daveId, officeId, .member, "Dave Smith", joinedDaysAgo: 38),
                member(sophiaId, officeId, .member, "Sophia Marchetti", joinedDaysAgo: 20),
            ]
        default:
            return []
        }
    }

    // MARK: - Leaderboards

    /// Curated leaderboard for a group + period. `all_time` never carries a rank
    /// delta (ADR-0064); week/month attach a deterministic delta to active
    /// members (the top entry is left `nil` to exercise the "no prior snapshot"
    /// case). Former members always have `rank == 0` and `rankDelta == nil` — they
    /// are unranked (Property 23) and render in a separate section.
    static func leaderboard(groupId: UUID, period: Period) -> [LeaderboardEntry] {
        let base = allTimeBoard(groupId)
        guard period != .allTime else { return base }
        return base.map { entry in
            guard !entry.isFormerMember, entry.rank > 1 else { return entry }
            let delta = entry.rank.isMultiple(of: 2) ? 1 : -1
            return LeaderboardEntry(
                userId: entry.userId,
                displayName: entry.displayName,
                avatarUrl: entry.avatarUrl,
                pintCount: entry.pintCount,
                rank: entry.rank,
                rankDelta: delta,
                isFormerMember: entry.isFormerMember
            )
        }
    }

    private static func allTimeBoard(_ groupId: UUID) -> [LeaderboardEntry] {
        switch groupId {
        case fridayId:
            return [
                // Dense-ranked tie at the top: both are rank 1 (both get the crown).
                entry(daveId, "Dave Smith", count: 12, rank: 1),
                entry(emmaId, "Emma Byrne", count: 12, rank: 1),
                entry(liamId, "Liam O'Neill", count: 8, rank: 2),   // dense: 2, not 3
                entry(oliviaId, "Olivia Reed", count: 3, rank: 3),
                // Former member: unranked, own section.
                LeaderboardEntry(
                    userId: fredId, displayName: "Fred Ashby", avatarUrl: nil,
                    pintCount: 5, rank: 0, rankDelta: nil, isFormerMember: true
                ),
            ]
        case sundayId:
            return [
                entry(emmaId, "Emma Byrne", count: 20, rank: 1),
                entry(daveId, "Dave Smith", count: 15, rank: 2),
                entry(noahId, "Noah Patel", count: 15, rank: 2),    // tie at rank 2
                entry(avaId, "Ava Lindqvist", count: 6, rank: 3),
            ]
        case officeId:
            return [
                entry(liamId, "Liam O'Neill", count: 9, rank: 1),
                entry(daveId, "Dave Smith", count: 4, rank: 2),
                entry(sophiaId, "Sophia Marchetti", count: 4, rank: 2),
            ]
        default:
            return []
        }
    }

    // MARK: - Pints
    //
    // ~15 pints across groups and members. A mix of: notes / no notes, every
    // drink type / no drink type, with / without location. Locations cluster
    // around central London so the map bounding-box query returns them.

    static let pints: [PintLog] = [
        // — Dave, Friday Club —
        pint(daveId, fridayId, note: "Crisp and cold.", drink: .lager,
             lat: 51.5074, lng: -0.1278, daysAgo: 1),
        pint(daveId, fridayId, note: nil, drink: .stout,
             lat: 51.5155, lng: -0.1410, daysAgo: 3),
        pint(daveId, fridayId, note: "Photo-only, no drink set.", drink: nil,
             lat: nil, lng: nil, daysAgo: 9),

        // — Dave, other groups (for the My Pints "All Groups" filter) —
        pint(daveId, sundayId, note: "Sunday session.", drink: .ale,
             lat: 51.4934, lng: -0.1000, daysAgo: 5),
        pint(daveId, officeId, note: nil, drink: .beer,
             lat: 51.5220, lng: -0.0900, daysAgo: 2),

        // — Emma, Friday Club —
        pint(emmaId, fridayId, note: "Best of the night.", drink: .cider,
             lat: 51.5100, lng: -0.1340, daysAgo: 1),
        pint(emmaId, fridayId, note: nil, drink: .beer,
             lat: 51.5090, lng: -0.1200, daysAgo: 4),

        // — Liam, Friday Club —
        pint(liamId, fridayId, note: "Guinness, obviously.", drink: .stout,
             lat: 51.5030, lng: -0.1500, daysAgo: 2),
        pint(liamId, fridayId, note: nil, drink: .lager,
             lat: nil, lng: nil, daysAgo: 6),

        // — Olivia, Friday Club —
        pint(oliviaId, fridayId, note: "First one this month!", drink: .ale,
             lat: 51.5180, lng: -0.1100, daysAgo: 7),

        // — Fred (former member), Friday Club: pints retained after leaving —
        pint(fredId, fridayId, note: "Still counts.", drink: .beer,
             lat: 51.5000, lng: -0.1450, daysAgo: 30),

        // — Sunday League —
        pint(emmaId, sundayId, note: nil, drink: .lager,
             lat: 51.4900, lng: -0.1050, daysAgo: 3),
        pint(noahId, sundayId, note: "Away day.", drink: .cider,
             lat: 51.4820, lng: -0.0800, daysAgo: 4),
        pint(avaId, sundayId, note: nil, drink: .ale, lat: nil, lng: nil, daysAgo: 8),

        // — Office Crew —
        pint(liamId, officeId, note: "After the standup.", drink: .beer,
             lat: 51.5210, lng: -0.0850, daysAgo: 1),
        pint(sophiaId, officeId, note: nil, drink: .stout,
             lat: 51.5240, lng: -0.0950, daysAgo: 5),
    ]

    // MARK: - Pending pints (offline queue)
    //
    // Two of the current user's pints in the local queue so My Pints (Task 17)
    // shows both badge states: one still uploading, one that gave up after
    // retries and offers retry / discard. The queue mechanics that produce these
    // land with Task 29; here they're static fixtures.

    static let pendingPints: [PendingPint] = [
        PendingPint(
            pint: pint(daveId, fridayId, note: "Uploading this one…", drink: .ale,
                       lat: 51.5145, lng: -0.1270, daysAgo: 0),
            status: .pending
        ),
        PendingPint(
            pint: pint(daveId, officeId, note: "Bad signal in the basement.", drink: .stout,
                       lat: nil, lng: nil, daysAgo: 0),
            status: .failed
        ),
    ]

    // MARK: - Builders

    private static func member(
        _ userId: UUID, _ groupId: UUID, _ role: GroupMemberRole,
        _ name: String, joinedDaysAgo days: Int
    ) -> GroupMember {
        GroupMember(
            id: UUID(), userId: userId, groupId: groupId, role: role,
            joinedAt: date(daysAgo: days), displayName: name, avatarUrl: nil
        )
    }

    private static func entry(
        _ userId: UUID, _ name: String, count: Int, rank: Int
    ) -> LeaderboardEntry {
        LeaderboardEntry(
            userId: userId, displayName: name, avatarUrl: nil,
            pintCount: count, rank: rank, rankDelta: nil, isFormerMember: false
        )
    }

    private static func pint(
        _ userId: UUID, _ groupId: UUID, note: String?, drink: DrinkType?,
        lat: Double?, lng: Double?, daysAgo days: Int
    ) -> PintLog {
        let location: Coordinate? = {
            guard let lat, let lng else { return nil }
            return Coordinate(latitude: lat, longitude: lng)
        }()
        return PintLog(
            id: UUID(), userId: userId, groupId: groupId,
            photoUrl: "pints/\(userId)/\(groupId)/\(UUID()).jpg",
            note: note, drinkType: drink, location: location,
            loggedAt: date(daysAgo: days)
        )
    }

    /// A fixed "now" for the mock world: 2026-07-01T12:00:00Z. Fixtures are dated
    /// relative to this rather than the wall clock so they stay deterministic
    /// across launches and test runs (e.g. the 24h delete window is stable).
    static let now = Date(timeIntervalSince1970: 1_782_734_400)

    /// A date `days` before `now`.
    private static func date(daysAgo days: Int) -> Date {
        now.addingTimeInterval(TimeInterval(-days * 86_400))
    }
}
