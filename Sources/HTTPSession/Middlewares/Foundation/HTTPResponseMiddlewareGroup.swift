import struct Foundation.Data
import HTTPTypes

protocol HTTPResponseHandler: Sendable {
    @Sendable func handle(
        _ response: HTTPDataResponse,
        from request: (HTTPRequest, Data?)
    ) async throws -> HTTPDataResponse
}

public actor HTTPResponseMiddlewareGroup: Sendable {
    private var middlewares: [any HTTPResponseMiddlewareProtocol]

    private let session: HTTPSession

    init(session: HTTPSession) {
        self.middlewares = []
        self.session = session
    }

    /// Adds the provided middleware to the beginning of the middleware chain.
    public func add(_ middleware: any HTTPResponseMiddlewareProtocol) {
        self.middlewares.append(middleware)
    }

    nonisolated func constructHandler() async throws -> any HTTPResponseHandler {
        let middlewares = await self.middlewares
        guard middlewares.count >= 1 else {
            return VoidHandler()
        }
        var currentHandler: any HTTPResponseHandler = FinalHandler(
            middleware: middlewares[0],
            session: self.session
        )
        guard middlewares.count > 1 else {
            return currentHandler
        }
        for i in (1..<middlewares.count).reversed() {
            let handler = Handler(
                middleware: middlewares[i],
                session: self.session,
                next: currentHandler.handle
            )
            currentHandler = handler
        }
        return currentHandler
    }
}

private struct VoidHandler: HTTPResponseHandler {
    @Sendable func handle(
        _ response: HTTPDataResponse, 
        from request: (HTTPRequest, Data?)
    ) async throws -> HTTPDataResponse {
        return response
    }
}

private struct FinalHandler: HTTPResponseHandler {
    let middleware: any HTTPResponseMiddlewareProtocol
    let session: HTTPSession

    @Sendable func handle(
        _ response: HTTPDataResponse,
        from request: (HTTPRequest, Data?)
    ) async throws -> HTTPDataResponse {
        try await self.middleware.handle(
            response,
            context: .init(
                request: request.0,
                requestData: request.1,
                session: self.session,
                next: { response, _ in return response }
            )
        )
    }
}

private struct Handler: HTTPResponseHandler {
    let middleware: any HTTPResponseMiddlewareProtocol
    let session: HTTPSession
    let next: @Sendable (HTTPDataResponse, (HTTPRequest, Data?)) async throws -> HTTPDataResponse

    @Sendable func handle(
        _ response: HTTPDataResponse,
        from request: (HTTPRequest, Data?)
    ) async throws -> HTTPDataResponse {
        return try await self.middleware.handle(
            response,
            context: .init(
                request: request.0,
                requestData: request.1,
                session: self.session,
                next: self.next
            )
        )
    }
}
