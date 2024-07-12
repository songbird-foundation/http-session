import struct Foundation.Data
import HTTPTypes

protocol HTTPResponseHandler: Sendable {
    @Sendable func handle(_ response: HTTPDataResponse) async throws -> HTTPDataResponse
}

public actor HTTPResponseMiddlewareGroup: Sendable {
    private var middlewares: [any HTTPResponseMiddlewareProtocol]

    private let session: HTTPSession

    init(session: HTTPSession, middlewares: [any HTTPResponseMiddlewareProtocol]) {
        self.middlewares = middlewares
        self.session = session
    }

    /// Adds the provided middleware to the beginning of the middleware chain.
    public func add(_ middleware: any HTTPResponseMiddlewareProtocol) {
        self.middlewares.append(middleware)
    }

    nonisolated func constructHandler(for request: (HTTPRequest, Data?)) async throws -> any HTTPResponseHandler {
        let middlewares = await self.middlewares
        guard middlewares.count >= 1 else {
            return VoidHandler()
        }
        var currentHandler: any HTTPResponseHandler = FinalHandler(
            middleware: middlewares[0],
            request: request,
            session: self.session
        )
        guard middlewares.count > 1 else {
            return currentHandler
        }
        for i in (1..<middlewares.count).reversed() {
            let handler = Handler(
                middleware: middlewares[i],
                session: self.session,
                request: request,
                next: currentHandler.handle
            )
            currentHandler = handler
        }
        return currentHandler
    }
}

private struct VoidHandler: HTTPResponseHandler {
    @Sendable func handle(_ response: HTTPDataResponse) async throws -> HTTPDataResponse {
        return response
    }
}

private struct FinalHandler: HTTPResponseHandler {
    let middleware: any HTTPResponseMiddlewareProtocol
    let request: (HTTPRequest, Data?)
    let session: HTTPSession

    @Sendable func handle(_ response: HTTPDataResponse) async throws -> HTTPDataResponse {
        try await self.middleware.handle(
            response,
            context: .init(
                request: self.request.0,
                requestData: self.request.1,
                session: self.session,
                next: { response in return response }
            )
        )
    }
}

private struct Handler: HTTPResponseHandler {
    let middleware: any HTTPResponseMiddlewareProtocol
    let session: HTTPSession
    let request: (HTTPRequest, Data?)
    let next: @Sendable (HTTPDataResponse) async throws -> HTTPDataResponse

    @Sendable func handle(_ response: HTTPDataResponse) async throws -> HTTPDataResponse {
        return try await self.middleware.handle(
            response,
            context: .init(
                request: self.request.0,
                requestData: self.request.1,
                session: self.session,
                next: self.next
            )
        )
    }
}
