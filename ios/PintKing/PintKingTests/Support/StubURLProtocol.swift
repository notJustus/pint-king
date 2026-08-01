//
//  StubURLProtocol.swift
//  PintKingTests
//
//  A URLProtocol that intercepts every request made through a session
//  configured with it, records what was sent, and replies with whatever the
//  test asked for. This is how NetworkClient gets exercised end-to-end — real
//  URLSession, real URLRequest construction, real header injection — with no
//  server and no network.
//
//  URLSession moves a request's `httpBody` into `httpBodyStream` before the
//  protocol sees it, so the body is read off the stream at intercept time and
//  recorded alongside the request; reading it later would be too late.
//

import Foundation

final class StubURLProtocol: URLProtocol {

    struct Response: Sendable {
        let statusCode: Int
        let data: Data
        /// When set, the request fails at the transport layer instead of
        /// returning an HTTP response — no status code ever reaches the client.
        let transportError: URLError?
        /// Held open for this long before answering, so a test can guarantee a
        /// second request overlaps with this one.
        let delay: TimeInterval

        init(statusCode: Int,
             data: Data = Data(),
             transportError: URLError? = nil,
             delay: TimeInterval = 0) {
            self.statusCode = statusCode
            self.data = data
            self.transportError = transportError
            self.delay = delay
        }

        /// Convenience for the common "200 with this JSON" case.
        static func json(_ json: String, statusCode: Int = 200, delay: TimeInterval = 0) -> Response {
            Response(statusCode: statusCode, data: Data(json.utf8), delay: delay)
        }

        static func transportFailure(_ code: URLError.Code = .notConnectedToInternet) -> Response {
            Response(statusCode: 0, transportError: URLError(code))
        }
    }

    struct RecordedRequest: Sendable {
        let request: URLRequest
        let body: Data?

        var path: String { request.url?.path ?? "" }
        var authorizationHeader: String? { request.value(forHTTPHeaderField: "Authorization") }
        var bodyString: String { body.map { String(decoding: $0, as: UTF8.self) } ?? "" }
    }

    /// A session wired to this stub. Ephemeral so nothing is cached between tests.
    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    /// Installs the responder and clears any previous recording. The handler is
    /// called for every intercepted request; it can branch on the URL, and on
    /// `recordedRequests` (which already includes the request being answered)
    /// to give a different answer the second time round.
    static func respond(_ handler: @escaping @Sendable (URLRequest) -> Response) {
        Storage.shared.reset(handler: handler)
    }

    /// Every request the client has made, in order.
    static var recordedRequests: [RecordedRequest] {
        Storage.shared.recordedRequests
    }

    /// How many requests have hit a given path — the usual way a test says
    /// "fail the first call, succeed the retry".
    static func requestCount(forPath path: String) -> Int {
        recordedRequests.filter { $0.path == path }.count
    }

    // MARK: - URLProtocol

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let recorded = RecordedRequest(request: request, body: Self.readBody(of: request))
        guard let handler = Storage.shared.record(recorded) else {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }

        let stub = handler(request)
        if stub.delay > 0 {
            // startLoading runs on URLSession's own thread, so blocking it holds
            // only this one request open.
            Thread.sleep(forTimeInterval: stub.delay)
        }
        if let transportError = stub.transportError {
            client?.urlProtocol(self, didFailWithError: transportError)
            return
        }
        let response = HTTPURLResponse(url: request.url!,
                                       statusCode: stub.statusCode,
                                       httpVersion: "HTTP/1.1",
                                       headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func readBody(of request: URLRequest) -> Data? {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return nil }

        stream.open()
        defer { stream.close() }

        var data = Data()
        let bufferSize = 4096
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: bufferSize)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }

    // MARK: - Shared state

    /// URLProtocol instances are created by URLSession on its own threads, so
    /// the handler and the recording live behind a lock.
    private final class Storage: @unchecked Sendable {
        static let shared = Storage()

        private let lock = NSLock()
        private var handler: (@Sendable (URLRequest) -> Response)?
        private var requests: [RecordedRequest] = []

        func reset(handler: @escaping @Sendable (URLRequest) -> Response) {
            lock.withLock {
                self.handler = handler
                self.requests = []
            }
        }

        /// Records the request and hands back the responder in one critical
        /// section, so a handler that reads `recordedRequests` always sees the
        /// request it is currently answering.
        func record(_ request: RecordedRequest) -> (@Sendable (URLRequest) -> Response)? {
            lock.withLock {
                requests.append(request)
                return handler
            }
        }

        var recordedRequests: [RecordedRequest] {
            lock.withLock { requests }
        }
    }
}
