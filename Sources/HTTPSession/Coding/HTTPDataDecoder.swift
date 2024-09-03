import Foundation
import HTTPTypes

public protocol HTTPDataDecoder: Sendable {
    /// Decodes a top-level value of the given type from the given data.
    ///
    /// - parameter type: The type of the value to decode.
    /// - parameter data: The data to decode from.
    /// - returns: A value of the requested type.
    /// - throws: An error if any value throws an error during decoding.
    func decode<T: Decodable>(_ type: T.Type, from data: Data, response: HTTPResponse) throws -> T
}

extension JSONDecoder: HTTPDataDecoder { 
    public func decode<T: Decodable>(_ type: T.Type, from data: Data, response: HTTPResponse) throws -> T {
        try self.decode(T.self, from: data)
    }
}
