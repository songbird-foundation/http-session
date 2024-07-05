import Foundation
import HTTPTypes

public protocol OAuth2Coordinator: Sendable {
    /// The current access token available locally.
    /// - Returns: An optional access token, if no token is returned, ``OAuth2Authenticator`` will fail with ``TokenError.missing``.
    func accessToken() async -> Token?

    /// Creates the request for a token refresh call.
    ///
    /// The request will be executed on the ``OAuth2Authenticator``'s ``HTTPSession``.
    /// `Data` is optional to allow e.g. `GET` requests, which do not contain bodies.
    func constructRefreshRequest(currentToken: Token?) throws -> (Data?, HTTPRequest)

    /// Processes the response, received from the request executed via ``OAuth2Coordinator/constructRefreshRequest()``.
    /// - Parameter response: The bare result, received from the session request.
    /// - Returns: A new token, derived from ``response``, used to execute the pending request.
    func processRefreshResponse(_ response: Result<(Data, HTTPResponse), any Error>) async throws -> Token

    /// Called if a ``TokenError`` occurs during a HTTP request.
    ///
    /// It allows you to perform appropriate side effects, e.g. showing a login form.
    /// You can also transform the error into anything you find appropriate.
    /// The default implementations returns the original ``TokenError``. without side effects.
    @Sendable func onTokenError(_ error: TokenError) async -> any Error
}

extension OAuth2Coordinator {
    @Sendable func onTokenError(_ error: TokenError) async -> any Error {
        return error
    }
}

/// An authenticator with a OAuth2 token refresh flow. 
///
/// It guarantees to execute not more than a single refresh at a time.
/// All subsequent calls will attach to the result of the current refresh 
/// and resume with the new token after the refresh is done.
///
/// As a rule of thumb, you should always use a single instance of 
/// ``OAuth2Authenticator`` per OAuth2 service or token provider.
///
/// The authenticator conforms to ``HTTPRequestMiddlewareProtocol``,
/// this allows you to easily add it to a ``HTTPSession``'s pipeline.
///
/// You can wrap the authenticator in another ``HTTPRequestMiddlewareProtocol`` to attach
/// the token only to specific requests (e.g. requests that satisfy a specific url prefix).
///
/// ```swift
/// struct MyOAuth2Middleware: HTTPRequestMiddlewareProtocol {
///     private let authenticator: OAuth2Authenticator
///
///     init(authenticator: OAuth2Authenticator) {
///         self.authenticator = authenticator
///     }
///
///     func handle(_ request: inout HTTPRequest) async throws {
///         guard request.url?.host() == "example.com" else { return }
///         let token = try await self.authenticator.validToken()
///         request.headerFields[.authorization] = "Bearer \(token.value)"
///     }
/// }
/// ```
public actor OAuth2Authenticator: HTTPRequestMiddlewareProtocol {
    let coordinator: any OAuth2Coordinator
    private let session: any HTTPSessionProtocol

    private var refreshTask: Task<Token, any Error>? = nil
    
    /// Creates a new OAuth2Authenticator.
    /// - Parameters:
    ///   - coordinator: The coordinator used to handle the refresh request on the authenticator.
    ///   - session: A session used to execute the refresh request on. This should normally not be the session the authenticator is a middleware on.
    public init(coordinator: any OAuth2Coordinator, session: HTTPSession = HTTPSession()) {
        self.coordinator = coordinator
        self.session = session
    }

    init(coordinator: any OAuth2Coordinator, sessionConformable: any HTTPSessionProtocol) {
        self.coordinator = coordinator
        self.session = sessionConformable
    }

    public func validToken(forceRefresh: Bool = false) async throws -> Token {
        if let handle = self.refreshTask {
            return try await handle.value
        }

        guard let token = await self.coordinator.accessToken() else {
            throw TokenError.missing
        }

        if token.isValid, !forceRefresh {
            return token
        }

        return try await refreshToken(current: token)
    }

    private func refreshToken(current token: Token? = nil) async throws -> Token {
        if let handle = self.refreshTask {
            return try await handle.value
        }

        let task = Task {
            defer { self.refreshTask = nil }

            let refreshRequest = try self.coordinator.constructRefreshRequest(currentToken: token)
            do {
                let response = if let data = refreshRequest.0 {
                    try await self.session.perform(refreshRequest.1, withData: data)
                } else {
                    try await self.session.perform(refreshRequest.1)
                }
                return try await self.coordinator.processRefreshResponse(.success(response))
            } catch {
                return try await self.coordinator.processRefreshResponse(.failure(error))
            }
        }

        self.refreshTask = task

        return try await task.value
    }

    @Sendable nonisolated public func handle(_ request: inout HTTPRequest) async throws {
        do {
            let token = try await self.validToken()
            request.headerFields[.authorization] = "Bearer \(token.value)"
        } catch let error as TokenError {
            throw await self.coordinator.onTokenError(error)
        }
    }
}
