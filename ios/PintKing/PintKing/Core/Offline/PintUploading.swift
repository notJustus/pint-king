//
//  PintUploading.swift
//  PintKing
//
//  The one network call the offline queue makes, behind a seam. The queue's job
//  is the *policy* — when to try, how often, when to give up — and none of that
//  needs a URLSession to be tested, so the transport is injected.
//
//  The real implementation goes through `NetworkClient` rather than talking to
//  URLSession directly, which is what gets a queued upload the JWT stamping and
//  the refresh-on-401 retry for free (ADR-0104). That matters more here than
//  anywhere else in the app: a pint can sit in the queue long enough for the
//  access token to expire before it is ever sent.
//

import Foundation

@MainActor
protocol PintUploading {
    /// Replays `POST /pints` for a queued pint. Throws `APIError` on failure —
    /// `.networkUnavailable` specifically means the request never reached the
    /// server, which the queue treats differently from a rejection.
    func upload(_ pint: QueuedPint, photoData: Data) async throws -> PintLog
}

struct NetworkPintUploader: PintUploading {

    private let client: NetworkClient

    init(client: NetworkClient) {
        self.client = client
    }

    func upload(_ pint: QueuedPint, photoData: Data) async throws -> PintLog {
        var form = MultipartFormData()
        // Field names are the API's `@RequestParam`s (PintController.createPint).
        form.addFile(name: "photo", filename: "pint.jpg", mimeType: "image/jpeg", data: photoData)
        form.addField(name: "note", value: pint.note)
        form.addField(name: "drinkType", value: pint.drinkType?.rawValue)
        form.addField(name: "latitude", value: pint.location.map { String($0.latitude) })
        form.addField(name: "longitude", value: pint.location.map { String($0.longitude) })

        let response: PintResponse = try await client.upload(.createPint, form: form)
        return response.asPintLog
    }
}

/// `POST /pints` response (PintController.PintResponse).
///
/// The API sends the coordinate flat — `latitude` / `longitude` as sibling
/// fields — while `PintLog` nests it in a `Coordinate`. Task 26 spotted the
/// mismatch and left it for whoever needed the endpoint first; this is that
/// caller, so the mapping lives here rather than distorting the domain model.
struct PintResponse: Decodable, Sendable {
    let id: UUID
    let userId: UUID
    let groupId: UUID
    let photoUrl: String
    let note: String?
    let drinkType: DrinkType?
    let latitude: Double?
    let longitude: Double?
    let loggedAt: Date

    var asPintLog: PintLog {
        // A pint has a location only if it has both halves of one.
        let location = zip2(latitude, longitude).map(Coordinate.init)
        return PintLog(
            id: id, userId: userId, groupId: groupId, photoUrl: photoUrl,
            note: note, drinkType: drinkType, location: location, loggedAt: loggedAt
        )
    }
}

/// Two optionals become one optional pair, or nothing.
private func zip2<A, B>(_ a: A?, _ b: B?) -> (A, B)? {
    guard let a, let b else { return nil }
    return (a, b)
}
