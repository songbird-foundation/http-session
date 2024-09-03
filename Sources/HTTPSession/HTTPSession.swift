import Foundation
import HTTPTypes

public final class HTTPSession: HTTPSessionProtocol, @unchecked Sendable {
    public let decoder: any HTTPDataDecoder
    public let encoder: any HTTPDataEncoder

    private let session: URLSession

    public let requestMiddlewares: HTTPRequestMiddlewareGroup
    public var responseMiddlewares: HTTPResponseMiddlewareGroup!

    public init(
        session: URLSession = .shared,
        decoder: any HTTPDataDecoder = JSONDecoder(),
        encoder: any HTTPDataEncoder = JSONEncoder(),
        requestMiddlewares: (any HTTPRequestMiddlewareProtocol)...,
        responseMiddlewares: (any HTTPResponseMiddlewareProtocol)...
    ) {
        self.session = session
        self.encoder = encoder
        self.decoder = decoder
        self.requestMiddlewares = HTTPRequestMiddlewareGroup(middlewares: requestMiddlewares)
        self.responseMiddlewares = HTTPResponseMiddlewareGroup(session: self, middlewares: responseMiddlewares)
    }

    /// Creates the final request (processed by all ``requestMiddlewares``)
    /// without executing a HTTP request with it.
    ///
    /// Can be used to execute the request in other environments, e.g. NukeUI image loading.
    public func finalize(request: HTTPRequest) async throws -> HTTPRequest {
        var request = request
        try await self.requestMiddlewares.handle(&request)
        return request
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
        let content = try self.decoder.decode(T.self, from: response.0, response: response.1)
        return (content, response.1)
    }

    public func execute<T: Decodable>(
        _ request: HTTPRequest,
        withData data: Data
    ) async throws -> (T, HTTPResponse) {
        let response: (Data, HTTPResponse) = try await self.perform(request, withData: data)
        let content = try self.decoder.decode(T.self, from: response.0, response: response.1)
        return (content, response.1)
    }

    public func execute<T: Decodable>(_ request: HTTPRequest) async throws -> (T, HTTPResponse) {
        let response: (Data, HTTPResponse) = try await self.perform(request)
        let content = try self.decoder.decode(T.self, from: response.0, response: response.1)
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
        let responseHandler = try await self.responseMiddlewares.constructHandler(for: (request, data))
        let response = try await responseHandler.handle((data: .data(rawResponse.0), response: rawResponse.1))
        return (rawResponse.0, response.response)
    }

    @discardableResult public func perform(
        _ request: HTTPRequest,
        withData data: Data
    ) async throws -> (Data, HTTPResponse) {
        var request = request
        try await self.requestMiddlewares.handle(&request)
        let rawResponse = try await self.session.upload(for: request, from: data)
        let responseHandler = try await self.responseMiddlewares.constructHandler(for: (request, data))
        let response = try await responseHandler.handle((data: .data(rawResponse.0), response: rawResponse.1))
        return (rawResponse.0, response.response)
    }

    @discardableResult public func perform(
        _ request: HTTPRequest
    ) async throws -> (Data, HTTPResponse) {
        var request = request
        try await self.requestMiddlewares.handle(&request)
        let rawResponse = try await self.session.data(for: request)
        let responseHandler = try await self.responseMiddlewares.constructHandler(for: (request, nil))
        let response = try await responseHandler.handle((data: .data(rawResponse.0), response: rawResponse.1))
        return (rawResponse.0, response.response)
    }

    public func bytes(_ request: HTTPRequest) async throws -> (URLSession.AsyncBytes, HTTPResponse) {
        var request = request
        try await self.requestMiddlewares.handle(&request)
        let (stream, rawResponse) = try await self.session.bytes(for: request)
        let responseHandler = try await self.responseMiddlewares.constructHandler(for: (request, nil))
        let response = try await responseHandler.handle((data: .stream(stream), response: rawResponse))
        return (stream, response.response)
    }

    public func execute(_ request: HTTPRequest, withData data: Data?) async throws -> (Data, HTTPResponse) {
        var request = request
        try await self.requestMiddlewares.handle(&request)
        let rawResponse = if let data {
            try await self.session.upload(for: request, from: data)
        } else {
            try await self.session.data(for: request)
        }
        let responseHandler = try await self.responseMiddlewares.constructHandler(for: (request, data))
        let response = try await responseHandler.handle((data: .data(rawResponse.0), response: rawResponse.1))
        return try (response.data.requireData(), response.response)
    }
}
