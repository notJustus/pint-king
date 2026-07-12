//
//  Enums.swift
//  PintKing
//
//  Shared enums whose raw values are the exact strings the API uses on the
//  wire (see l3-database.md CHECK constraints and l3-api.md query params).
//

import Foundation

/// Drink category on a pint log. Raw values match the DB CHECK constraint
/// on `pint_logs.drink_type`. `allCases` order is the post-capture picker order.
enum DrinkType: String, Codable, CaseIterable, Sendable {
    case beer
    case lager
    case ale
    case stout
    case cider
}

/// Leaderboard / map time-period filter. Raw values match the API's
/// `?period=` query parameter (snake_case).
enum Period: String, Codable, CaseIterable, Sendable {
    case allTime = "all_time"
    case thisWeek = "this_week"
    case thisMonth = "this_month"
}

/// A member's role within a group. Raw values match the DB CHECK constraint
/// on `group_members.role`.
enum GroupMemberRole: String, Codable, CaseIterable, Sendable {
    case admin
    case member
}
