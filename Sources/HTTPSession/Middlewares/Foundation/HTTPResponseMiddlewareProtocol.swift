import Foundation
import HTTPTypes

public enum HTTPResponseError: Error {
    case unexpectedPayload
}

public enum HTTPResponsePayload {
    case stream(URLSession.AsyncBytes)
    case data(Data)

    public init(_ data: Data) {
        self = .data(data)
    }

    public init(_ stream: URLSession.AsyncBytes) {
        self = .stream(stream)
    }

    public func requireData() throws -> Data {
        switch self {
        case .stream:
            throw HTTPResponseError.unexpectedPayload
        case .data(let data):
            return data
        }
    }
}

public struct HTTPDataResponse {
    public let data: HTTPResponsePayload
    public let response: HTTPResponse
}

/// Used to create middlewares to process responses received from an implementation of ``HTTPSessionProtocol``.
///
/// Such middlewares should not be used to process successful responses. They should be used to throw (and decode) errors from the response.
/// The Data to Swift Type decoding will be handled after all the middlewares have been passed successfully.
///
/// - Note: Be aware that forwarding a modified ``HTTPResponsePayload`` to subsequent middlewares does not affect the end result.
///         ``HTTPSession`` will always return/decode the "true" data received by the request.
///         ``HTTPResponsePayload`` is only forwarded to allow decoding error's or any other non success responses.
public protocol HTTPResponseMiddlewareProtocol: Sendable {
    func handle(
        _ response: HTTPDataResponse,
        context: HTTPResponseMiddlewareContext
    ) async throws -> HTTPDataResponse
}

public struct HTTPResponseMiddlewareContext: Sendable {
    public let request: HTTPRequest
    public let session: HTTPSession
    public let next: @Sendable (HTTPDataResponse, HTTPRequest) async throws -> HTTPDataResponse
}
