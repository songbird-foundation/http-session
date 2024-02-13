import Foundation
import HTTPTypes
import HTTPTypesFoundation

/// A protocol to implement a network layer.
protocol HTTPSessionProtocol: Sendable {

    /// The decoder used to decode the data returned from the endpoint.
    var decoder: HTTPDataDecoder { get }

    /// The encoder used to encode the body data for the request.
    var encoder: HTTPDataEncoder { get }

    var requestMiddlewares: HTTPRequestMiddlewareGroup { get }
    var responseMiddlewares: HTTPResponseMiddlewareGroup { get }

    func execute<T: Decodable, D: Encodable>(
        _ request: HTTPRequest,
        withContent data: D
    ) async throws -> (T, HTTPResponse)

    func execute<T: Decodable>(
        _ request: HTTPRequest,
        withData data: Data
    ) async throws -> (T, HTTPResponse)

    func execute<T: Decodable>(
        _ request: HTTPRequest
    ) async throws -> (T, HTTPResponse)
    
    @discardableResult func perform<D: Encodable>(
        _ request: HTTPRequest,
        withContent data: D
    ) async throws -> (Data, HTTPResponse)

    @discardableResult func perform(
        _ request: HTTPRequest,
        withData data: Data
    ) async throws -> (Data, HTTPResponse)

    @discardableResult func perform(
        _ request: HTTPRequest
    ) async throws -> (Data, HTTPResponse)

    func bytes(_ request: HTTPRequest) async throws -> (URLSession.AsyncBytes, HTTPResponse)
}
