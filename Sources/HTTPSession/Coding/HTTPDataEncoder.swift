import Foundation
import HTTPTypes

public protocol HTTPDataEncoder: Sendable {
    /// Encodes the given top-level value and returns its encoded representation.
    ///
    /// - parameter value: The value to encode.
    /// - returns: A new `Data` value containing the encoded data.
    /// - throws: An error if any value throws an error during encoding.
    func encode<T: Encodable>(_ value: T, for request: HTTPRequest) throws -> Data
}

extension JSONEncoder: HTTPDataEncoder {
    public func encode<T: Encodable>(_ value: T, for request: HTTPRequest) throws -> Data {
        try self.encode(value)
    }
}
