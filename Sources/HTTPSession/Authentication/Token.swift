import Foundation

/// A generic token, which can be stored locally, preferably in `SecKeychain`.
///
/// It contains a ``Token.value`` and an ``Token.expiration``.
/// The expiration is used to indicate if the token already expired without the
/// need of communication with the server.
///
/// The token is used in the provided ``BearerTokenMiddleware``.
public struct Token: Sendable, Codable, Equatable, Hashable {
    public var value: String
    public var expiration: Date

    /// Indicates if the token is still valid, computed using ``expiration``.
    public var isValid: Bool {
        expiration.timeIntervalSinceNow > 0
    }

    public init(value: String, expiration: Date) {
        self.value = value
        self.expiration = expiration
    }
}

public enum TokenError: Sendable, Error {
    case missing
    case expired
}
