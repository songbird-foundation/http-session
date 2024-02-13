import HTTPTypes

public struct BearerTokenMiddleware: HTTPRequestMiddlewareProtocol {
    private let token: @Sendable (HTTPRequest) async throws -> Token?

    public init(token: @Sendable @escaping (HTTPRequest) -> Token?) {
        self.token = token
    }

    public func handle(_ request: inout HTTPRequest) async throws {
        guard let token = try await self.token(request) else {
            throw TokenError.missing
        }
        guard token.isValid else {
            throw TokenError.expired
        }
        request.headerFields[.authorization] = "Bearer \(token.value)"
    }
}
