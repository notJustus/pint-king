//
//  Endpoint.swift
//  PintKing
//
//  Every API call the app can make, as one value type. An Endpoint knows its
//  path, method, query items, JSON body, and whether it needs a JWT — and turns
//  all of that into a URLRequest. It knows nothing about tokens, retries, or
//  URLSession; NetworkClient adds those. Paths and parameter names mirror the
//  endpoint catalogue in l3-api.md §1 exactly.
//

import Foundation

enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case patch = "PATCH"
    case delete = "DELETE"
}

enum Endpoint: Sendable {

    // MARK: Auth

    case appleAuth(identityToken: String)
    case refresh(refreshToken: String)
    case logout

    // MARK: Users

    case getProfile
    /// PATCH semantics on the API are "omitted means unchanged" — a nil field is
    /// left out of the JSON entirely (Swift synthesises `encodeIfPresent` for
    /// optionals), so a nil never reads as "clear this value".
    case updateProfile(displayName: String?, activeGroupId: UUID?)
    case uploadAvatar
    case deleteAccount

    // MARK: Groups

    case createGroup(name: String)
    case joinGroup(inviteCode: String)
    case listGroups
    case getGroup(id: UUID)
    case updateGroup(id: UUID, name: String)
    /// Removing yourself *is* leaving — same endpoint, `userId` is the caller.
    case removeMember(groupId: UUID, userId: UUID)
    case promoteMember(groupId: UUID, userId: UUID)
    case regenerateInviteCode(groupId: UUID)

    // MARK: Pints

    /// Multipart (photo + metadata); the body is supplied by `NetworkClient.upload`.
    case createPint
    case listPints(groupId: UUID, period: Period?, page: Int?, size: Int?)
    case updatePint(id: UUID, note: String?, drinkType: DrinkType?)
    case deletePint(id: UUID)

    // MARK: Leaderboard

    case leaderboard(groupId: UUID, period: Period)

    // MARK: Map

    case mapPints(groupId: UUID, scope: MapScope, southWest: Coordinate, northEast: Coordinate)

    // MARK: - Request description

    var path: String {
        switch self {
        case .appleAuth: "/auth/apple"
        case .refresh: "/auth/refresh"
        case .logout: "/auth/logout"

        case .getProfile, .updateProfile, .deleteAccount: "/users/me"
        case .uploadAvatar: "/users/me/avatar"

        case .createGroup, .listGroups: "/groups"
        case .joinGroup: "/groups/join"
        case .getGroup(let id), .updateGroup(let id, _): "/groups/\(id.uuidString)"
        case .removeMember(let groupId, let userId):
            "/groups/\(groupId.uuidString)/members/\(userId.uuidString)"
        case .promoteMember(let groupId, let userId):
            "/groups/\(groupId.uuidString)/members/\(userId.uuidString)/promote"
        case .regenerateInviteCode(let groupId):
            "/groups/\(groupId.uuidString)/invite-code/regenerate"

        case .createPint, .listPints: "/pints"
        case .updatePint(let id, _, _), .deletePint(let id): "/pints/\(id.uuidString)"

        case .leaderboard(let groupId, _): "/groups/\(groupId.uuidString)/leaderboard"

        case .mapPints: "/pints/map"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .getProfile, .listGroups, .getGroup, .listPints, .leaderboard, .mapPints:
            .get
        case .appleAuth, .refresh, .logout, .uploadAvatar, .createGroup, .joinGroup,
             .promoteMember, .regenerateInviteCode, .createPint:
            .post
        case .updateProfile, .updateGroup, .updatePint:
            .patch
        case .deleteAccount, .removeMember, .deletePint:
            .delete
        }
    }

    /// False only for the two endpoints that establish a session. `refresh`
    /// authenticates with the refresh token in its body, not a JWT — which is
    /// also what stops the 401 handler from recursing into itself.
    var requiresAuthentication: Bool {
        switch self {
        case .appleAuth, .refresh: false
        default: true
        }
    }

    var queryItems: [URLQueryItem] {
        switch self {
        case .listPints(let groupId, let period, let page, let size):
            var items = [URLQueryItem(name: "group_id", value: groupId.uuidString)]
            if let period { items.append(URLQueryItem(name: "period", value: period.rawValue)) }
            if let page { items.append(URLQueryItem(name: "page", value: String(page))) }
            if let size { items.append(URLQueryItem(name: "size", value: String(size))) }
            return items

        case .leaderboard(_, let period):
            return [URLQueryItem(name: "period", value: period.rawValue)]

        case .mapPints(let groupId, let scope, let southWest, let northEast):
            return [
                URLQueryItem(name: "group_id", value: groupId.uuidString),
                URLQueryItem(name: "scope", value: scope.rawValue),
                URLQueryItem(name: "sw_lat", value: String(southWest.latitude)),
                URLQueryItem(name: "sw_lng", value: String(southWest.longitude)),
                URLQueryItem(name: "ne_lat", value: String(northEast.latitude)),
                URLQueryItem(name: "ne_lng", value: String(northEast.longitude))
            ]

        default:
            return []
        }
    }

    /// The JSON body, or nil for endpoints that carry none (GET/DELETE, and the
    /// multipart uploads whose body `NetworkClient.upload` supplies instead).
    func body() throws -> Data? {
        let encoder = JSONCoding.encoder
        switch self {
        case .appleAuth(let identityToken):
            return try encoder.encode(AppleAuthBody(identityToken: identityToken))
        case .refresh(let refreshToken):
            return try encoder.encode(RefreshBody(refreshToken: refreshToken))
        case .updateProfile(let displayName, let activeGroupId):
            return try encoder.encode(UpdateProfileBody(displayName: displayName, activeGroupId: activeGroupId))
        case .createGroup(let name):
            return try encoder.encode(NameBody(name: name))
        case .joinGroup(let inviteCode):
            return try encoder.encode(JoinGroupBody(inviteCode: inviteCode))
        case .updateGroup(_, let name):
            return try encoder.encode(NameBody(name: name))
        case .updatePint(_, let note, let drinkType):
            return try encoder.encode(UpdatePintBody(note: note, drinkType: drinkType))
        default:
            return nil
        }
    }

    /// Builds the URLRequest. The Authorization header is *not* set here — that
    /// belongs to NetworkClient, which owns the token and may re-stamp it on a
    /// retry after refreshing.
    func makeRequest(baseURL: URL) throws -> URLRequest {
        // Unreachable for any valid base URL: a URL always decomposes into components.
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw APIError.serverError
        }
        // Every `path` starts with "/", so drop a trailing slash on the base
        // rather than emitting "//users/me".
        var basePath = components.path
        if basePath.hasSuffix("/") { basePath.removeLast() }
        components.path = basePath + path

        let items = queryItems
        components.queryItems = items.isEmpty ? nil : items

        guard let url = components.url else { throw APIError.serverError }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        if let body = try body() {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return request
    }
}

// MARK: - Request bodies

// Private to this file: these exist only to shape JSON on the wire. Their
// property names are the API's field names (camelCase, per JSONCoding).

private struct AppleAuthBody: Encodable {
    let identityToken: String
}

private struct RefreshBody: Encodable {
    let refreshToken: String
}

private struct UpdateProfileBody: Encodable {
    let displayName: String?
    let activeGroupId: UUID?
}

/// Shared by group create and rename — both send `{ "name": ... }`.
private struct NameBody: Encodable {
    let name: String
}

private struct JoinGroupBody: Encodable {
    let inviteCode: String
}

private struct UpdatePintBody: Encodable {
    let note: String?
    let drinkType: DrinkType?
}
