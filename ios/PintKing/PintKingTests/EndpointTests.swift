//
//  EndpointTests.swift
//  PintKingTests
//
//  Task 26: the Endpoint enum is the app's copy of the API's endpoint catalogue
//  (l3-api.md §1). These tests pin the parts a typo would silently break —
//  paths, methods, query parameter *names* (snake_case on the wire, unlike the
//  camelCase bodies), and the omit-nil PATCH encoding.
//

import Foundation
import Testing
@testable import PintKing

struct EndpointTests {

    let baseURL = URL(string: "https://api.pintking.test")!

    // MARK: - Paths and methods

    @Test func pathsAreAppendedToTheBaseURL() throws {
        let request = try Endpoint.getProfile.makeRequest(baseURL: baseURL)

        #expect(request.url?.absoluteString == "https://api.pintking.test/users/me")
        #expect(request.httpMethod == "GET")
    }

    @Test func pathParametersAreInterpolated() throws {
        let groupId = UUID()
        let userId = UUID()

        let promote = try Endpoint.promoteMember(groupId: groupId, userId: userId).makeRequest(baseURL: baseURL)
        #expect(promote.url?.path == "/groups/\(groupId.uuidString)/members/\(userId.uuidString)/promote")
        #expect(promote.httpMethod == "POST")

        // Leaving a group is removing yourself — same endpoint, DELETE.
        let leave = try Endpoint.removeMember(groupId: groupId, userId: userId).makeRequest(baseURL: baseURL)
        #expect(leave.url?.path == "/groups/\(groupId.uuidString)/members/\(userId.uuidString)")
        #expect(leave.httpMethod == "DELETE")
    }

    // MARK: - Query items

    @Test func mapQueryUsesSnakeCaseBoundingBoxParameters() throws {
        let groupId = UUID()
        let endpoint = Endpoint.mapPints(groupId: groupId,
                                         scope: .personal,
                                         southWest: Coordinate(latitude: 51.0, longitude: -0.5),
                                         northEast: Coordinate(latitude: 52.0, longitude: 0.5))

        let request = try endpoint.makeRequest(baseURL: baseURL)
        let url = try #require(request.url)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let query = try #require(components.queryItems)
        let values = Dictionary(uniqueKeysWithValues: query.map { ($0.name, $0.value ?? "") })

        #expect(request.url?.path == "/pints/map")
        #expect(values["group_id"] == groupId.uuidString)
        #expect(values["scope"] == "personal")
        #expect(values["sw_lat"] == "51.0")
        #expect(values["sw_lng"] == "-0.5")
        #expect(values["ne_lat"] == "52.0")
        #expect(values["ne_lng"] == "0.5")
    }

    @Test func optionalListParametersAreOmittedWhenNil() throws {
        let groupId = UUID()

        let bare = try Endpoint.listPints(groupId: groupId, period: nil, page: nil, size: nil)
            .makeRequest(baseURL: baseURL)
        #expect(bare.url?.query == "group_id=\(groupId.uuidString)")

        let filtered = try Endpoint.listPints(groupId: groupId, period: .thisWeek, page: 2, size: 20)
            .makeRequest(baseURL: baseURL)
        let query = try #require(filtered.url?.query)
        #expect(query.contains("period=this_week"))   // snake_case raw value
        #expect(query.contains("page=2"))
        #expect(query.contains("size=20"))
    }

    @Test func endpointsWithoutQueryItemsHaveNoQueryString() throws {
        let request = try Endpoint.listGroups.makeRequest(baseURL: baseURL)
        #expect(request.url?.query == nil)
    }

    // MARK: - Bodies

    @Test func jsonBodiesAreEncodedWithAContentTypeHeader() throws {
        let request = try Endpoint.createGroup(name: "Sunday Club").makeRequest(baseURL: baseURL)
        let body = try #require(request.httpBody)

        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(String(decoding: body, as: UTF8.self) == #"{"name":"Sunday Club"}"#)
    }

    @Test func nilPatchFieldsAreOmittedRatherThanSentAsNull() throws {
        // The API treats an absent field as "leave unchanged" (UserService), so
        // a nil must never appear on the wire as an explicit null.
        let groupId = UUID()
        let request = try Endpoint.updateProfile(displayName: nil, activeGroupId: groupId)
            .makeRequest(baseURL: baseURL)
        let body = String(decoding: try #require(request.httpBody), as: UTF8.self)

        #expect(body.contains("activeGroupId"))
        #expect(body.contains("displayName") == false)
        #expect(request.httpMethod == "PATCH")
    }

    @Test func drinkTypeIsEncodedAsItsWireString() throws {
        let request = try Endpoint.updatePint(id: UUID(), note: "Crisp", drinkType: .stout)
            .makeRequest(baseURL: baseURL)
        let body = String(decoding: try #require(request.httpBody), as: UTF8.self)

        #expect(body.contains(#""drinkType":"stout""#))
        #expect(body.contains(#""note":"Crisp""#))
    }

    @Test func bodylessEndpointsCarryNoBodyOrContentType() throws {
        let request = try Endpoint.deletePint(id: UUID()).makeRequest(baseURL: baseURL)

        #expect(request.httpBody == nil)
        #expect(request.value(forHTTPHeaderField: "Content-Type") == nil)
    }

    // MARK: - Authentication

    @Test func onlySessionEstablishingEndpointsSkipAuthentication() {
        #expect(Endpoint.appleAuth(identityToken: "t").requiresAuthentication == false)
        #expect(Endpoint.refresh(refreshToken: "r").requiresAuthentication == false)

        #expect(Endpoint.logout.requiresAuthentication)
        #expect(Endpoint.getProfile.requiresAuthentication)
        #expect(Endpoint.createPint.requiresAuthentication)
    }

    @Test func endpointNeverSetsTheAuthorizationHeaderItself() throws {
        // The token belongs to NetworkClient, which may re-stamp it on a retry.
        let request = try Endpoint.getProfile.makeRequest(baseURL: baseURL)
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
    }
}
