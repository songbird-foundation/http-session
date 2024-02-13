import HTTPTypes

public protocol HTTPRequestMiddlewareProtocol: Sendable {
    func handle(_ request: inout HTTPRequest) async throws
}
