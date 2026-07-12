//
//  DomainModelsTests.swift
//  PintKingTests
//
//  Task 2: domain models and shared types. These tests pin the JSON wire
//  contract the (future) Kotlin/Spring API produces — camelCase keys,
//  lowercase / snake_case enum values, ISO 8601 UTC timestamps — and prove
//  every Codable model survives an encode → decode round-trip unchanged.
//

import Foundation
import Testing
@testable import PintKing

struct DomainModelsTests {

    // A whole-second date: `.iso8601` drops fractional seconds, so using a
    // clean second-boundary keeps round-trips exact.
    private let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)

    // MARK: - Round-trip helper

    /// Encode then decode a value with the shared PintKing coders and assert equality.
    private func roundTrip<T: Codable & Equatable>(_ value: T) throws -> T {
        let data = try JSONCoding.encoder.encode(value)
        return try JSONCoding.decoder.decode(T.self, from: data)
    }

    // MARK: - Round-trip tests (one per model)

    @Test func userRoundTrips() throws {
        let user = User(
            id: UUID(),
            appleId: "000123.abcdef.0001",
            displayName: "Dave Smith",
            avatarUrl: "avatars/abc/1.jpg",
            activeGroupId: UUID()
        )
        #expect(try roundTrip(user) == user)
    }

    @Test func userWithNilOptionalsRoundTrips() throws {
        let user = User(
            id: UUID(),
            appleId: "000123.abcdef.0002",
            displayName: "User",
            avatarUrl: nil,
            activeGroupId: nil
        )
        #expect(try roundTrip(user) == user)
    }

    @Test func groupRoundTrips() throws {
        let group = Group(
            id: UUID(),
            name: "Friday Club",
            inviteCode: "aB3dE6fH",
            createdBy: UUID(),
            createdAt: fixedDate
        )
        #expect(try roundTrip(group) == group)
    }

    @Test func groupMemberRoundTrips() throws {
        let member = GroupMember(
            id: UUID(),
            userId: UUID(),
            groupId: UUID(),
            role: .admin,
            joinedAt: fixedDate,
            displayName: "Dave Smith",
            avatarUrl: nil
        )
        #expect(try roundTrip(member) == member)
    }

    @Test func pintLogRoundTrips() throws {
        let pint = PintLog(
            id: UUID(),
            userId: UUID(),
            groupId: UUID(),
            photoUrl: "pints/abc/def/1.jpg",
            note: "Crisp and cold.",
            drinkType: .stout,
            location: Coordinate(latitude: 51.5074, longitude: -0.1278),
            loggedAt: fixedDate
        )
        #expect(try roundTrip(pint) == pint)
    }

    @Test func pintLogWithNilOptionalsRoundTrips() throws {
        let pint = PintLog(
            id: UUID(),
            userId: UUID(),
            groupId: UUID(),
            photoUrl: "pints/abc/def/2.jpg",
            note: nil,
            drinkType: nil,
            location: nil,
            loggedAt: fixedDate
        )
        #expect(try roundTrip(pint) == pint)
    }

    @Test func leaderboardEntryRoundTrips() throws {
        let entry = LeaderboardEntry(
            userId: UUID(),
            displayName: "Dave Smith",
            avatarUrl: nil,
            pintCount: 12,
            rank: 1,
            rankDelta: 2,
            isFormerMember: false
        )
        #expect(try roundTrip(entry) == entry)
    }

    @Test func leaderboardEntryWithNilDeltaRoundTrips() throws {
        // rankDelta is null for All-Time and for members with no prior snapshot.
        let entry = LeaderboardEntry(
            userId: UUID(),
            displayName: "Former Fred",
            avatarUrl: nil,
            pintCount: 3,
            rank: 5,
            rankDelta: nil,
            isFormerMember: true
        )
        #expect(try roundTrip(entry) == entry)
    }

    @Test func coordinateRoundTrips() throws {
        let coord = Coordinate(latitude: -33.8688, longitude: 151.2093)
        #expect(try roundTrip(coord) == coord)
    }

    // MARK: - Wire-contract decode tests (pin exact key names & value formats)

    @Test func userDecodesFromApiJson() throws {
        let json = """
        {
          "id": "11111111-1111-1111-1111-111111111111",
          "appleId": "000123.abcdef.0001",
          "displayName": "Dave Smith",
          "avatarUrl": "avatars/abc/1.jpg",
          "activeGroupId": "22222222-2222-2222-2222-222222222222"
        }
        """
        let user = try JSONCoding.decoder.decode(User.self, from: Data(json.utf8))
        #expect(user.id == UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        #expect(user.displayName == "Dave Smith")
        #expect(user.activeGroupId == UUID(uuidString: "22222222-2222-2222-2222-222222222222"))
    }

    @Test func pintLogDecodesIso8601TimestampAndLowercaseDrinkType() throws {
        let json = """
        {
          "id": "11111111-1111-1111-1111-111111111111",
          "userId": "22222222-2222-2222-2222-222222222222",
          "groupId": "33333333-3333-3333-3333-333333333333",
          "photoUrl": "pints/a/b/1.jpg",
          "note": "Lovely",
          "drinkType": "lager",
          "location": { "latitude": 51.5, "longitude": -0.12 },
          "loggedAt": "2024-01-15T14:30:00Z"
        }
        """
        let pint = try JSONCoding.decoder.decode(PintLog.self, from: Data(json.utf8))
        #expect(pint.drinkType == .lager)
        #expect(pint.location == Coordinate(latitude: 51.5, longitude: -0.12))
        // 2024-01-15T14:30:00Z == 1705329000 seconds since epoch.
        #expect(pint.loggedAt == Date(timeIntervalSince1970: 1_705_329_000))
    }

    @Test func leaderboardEntryDecodesNullDelta() throws {
        let json = """
        {
          "userId": "22222222-2222-2222-2222-222222222222",
          "displayName": "Dave",
          "avatarUrl": null,
          "pintCount": 7,
          "rank": 2,
          "rankDelta": null,
          "isFormerMember": false
        }
        """
        let entry = try JSONCoding.decoder.decode(LeaderboardEntry.self, from: Data(json.utf8))
        #expect(entry.rankDelta == nil)
        #expect(entry.avatarUrl == nil)
        #expect(entry.pintCount == 7)
    }

    // MARK: - Enum raw-value tests

    @Test(arguments: [
        (DrinkType.beer, "beer"),
        (DrinkType.lager, "lager"),
        (DrinkType.ale, "ale"),
        (DrinkType.stout, "stout"),
        (DrinkType.cider, "cider"),
    ])
    func drinkTypeRawValuesMatchApi(_ type: DrinkType, _ raw: String) {
        #expect(type.rawValue == raw)
    }

    @Test(arguments: [
        (Period.allTime, "all_time"),
        (Period.thisWeek, "this_week"),
        (Period.thisMonth, "this_month"),
    ])
    func periodRawValuesMatchApi(_ period: Period, _ raw: String) {
        #expect(period.rawValue == raw)
    }

    @Test func groupMemberRoleRawValuesMatchApi() {
        #expect(GroupMemberRole.admin.rawValue == "admin")
        #expect(GroupMemberRole.member.rawValue == "member")
    }

    @Test func drinkTypeIsCaseIterableInMenuOrder() {
        // Post-capture picker chips render in this order: Beer, Lager, Ale, Stout, Cider.
        #expect(DrinkType.allCases == [.beer, .lager, .ale, .stout, .cider])
    }

    // MARK: - APIError HTTP status mapping

    @Test(arguments: [
        (200, APIError?.none),
        (201, APIError?.none),
        (204, APIError?.none),
        (400, .validationFailed),
        (401, .unauthorized),
        (403, .forbidden),
        (404, .notFound),
        (409, .conflict),
        (422, .validationFailed),
        (500, .serverError),
        (503, .serverError),
        (418, .serverError),
    ])
    func apiErrorMapsFromStatusCode(_ status: Int, _ expected: APIError?) {
        #expect(APIError.from(statusCode: status) == expected)
    }
}
