import Foundation
import HTTPTypes

public final class HTTPSession: HTTPSessionProtocol {
    let decoder: HTTPDataDecoder
    let encoder: HTTPDataEncoder

    private let session: URLSession

    public let requestMiddlewares = HTTPRequestMiddlewareGroup()
    public let responseMiddlewares = HTTPResponseMiddlewareGroup()

    public init(
        session: URLSession = .shared,
        decoder: HTTPDataDecoder = JSONDecoder(),
        encoder: HTTPDataEncoder = JSONEncoder()
    ) {
        self.session = session
        self.encoder = encoder
        self.decoder = decoder
    }

    public func execute<T: Decodable, D: Encodable>(
        _ request: HTTPRequest,
        withContent data: D
    ) async throws -> T {
        try await self.execute(request, withContent: data).0
    }

    public func execute<T: Decodable>(
        _ request: HTTPRequest,
        withData data: Data
    ) async throws -> T {
        try await self.execute(request, withData: data).0
    }

    public func execute<T: Decodable>(_ request: HTTPRequest) async throws -> T {
        try await self.execute(request).0
    }

    public func execute<T: Decodable, D: Encodable>(
        _ request: HTTPRequest,
        withContent data: D
    ) async throws -> (T, HTTPResponse) {
        let response: (Data, HTTPResponse) = try await self.perform(request, withContent: data)
        let content = try self.decoder.decode(T.self, from: (.data(response.0), response.1))
        return (content, response.1)
    }

    public func execute<T: Decodable>(
        _ request: HTTPRequest,
        withData data: Data
    ) async throws -> (T, HTTPResponse) {
        let response: (Data, HTTPResponse) = try await self.perform(request, withData: data)
        let content = try self.decoder.decode(T.self, from: (.data(response.0), response.1))
        return (content, response.1)
    }

    public func execute<T: Decodable>(_ request: HTTPRequest) async throws -> (T, HTTPResponse) {
        let response: (Data, HTTPResponse) = try await self.perform(request)
        let content = try self.decoder.decode(T.self, from: (.data(response.0), response.1))
        return (content, response.1)
    }

    @discardableResult public func perform<D: Encodable>(
        _ request: HTTPRequest,
        withContent data: D
    ) async throws -> (Data, HTTPResponse) {
        var request = request
        try await self.requestMiddlewares.handle(&request)
        let data = try self.encoder.encode(data, for: request)
        let rawResponse = try await self.session.upload(for: request, from: data)
        let responseHandler = try await self.responseMiddlewares.constructHandler()
        let (_, response) = try await responseHandler.handle((.data(rawResponse.0), rawResponse.1))
        return (rawResponse.0, response)
    }

    @discardableResult public func perform(
        _ request: HTTPRequest,
        withData data: Data
    ) async throws -> (Data, HTTPResponse) {
        var request = request
        try await self.requestMiddlewares.handle(&request)
        let rawResponse = try await self.session.upload(for: request, from: data)
        let responseHandler = try await self.responseMiddlewares.constructHandler()
        let (_, response) = try await responseHandler.handle((.data(rawResponse.0), rawResponse.1))
        return (rawResponse.0, response)
    }

    @discardableResult public func perform(
        _ request: HTTPRequest
    ) async throws -> (Data, HTTPResponse) {
        var request = request
        try await self.requestMiddlewares.handle(&request)
        let rawResponse = try await self.session.data(for: request)
        let responseHandler = try await self.responseMiddlewares.constructHandler()
        let (_, response) = try await responseHandler.handle((.data(rawResponse.0), rawResponse.1))
        return (rawResponse.0, response)
    }

    func bytes(_ request: HTTPRequest) async throws -> (URLSession.AsyncBytes, HTTPResponse) {
        var request = request
        try await self.requestMiddlewares.handle(&request)
        let (stream, rawResponse) = try await self.session.bytes(for: request)
        let responseHandler = try await self.responseMiddlewares.constructHandler()
        let (_, response) = try await responseHandler.handle((.stream(stream), rawResponse))
        return (stream, response)
    }
}
