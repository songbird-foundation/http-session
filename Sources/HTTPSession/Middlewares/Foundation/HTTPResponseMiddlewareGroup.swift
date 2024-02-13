protocol HTTPResponseHandler {
    @Sendable func handle(_ response: HTTPDataResponse) async throws -> HTTPDataResponse
}

public actor HTTPResponseMiddlewareGroup: Sendable {
    private var middlewares: [any HTTPResponseMiddlewareProtocol]

    public init() {
        self.middlewares = []
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
        var currentHandler: any HTTPResponseHandler = FinalHandler(middleware: middlewares[0])
        guard middlewares.count > 1 else {
            return currentHandler
        }
        for i in (1..<middlewares.count).reversed() {
            let handler = Handler(middleware: middlewares[i], next: currentHandler.handle(_:))
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

    @Sendable func handle(_ response: HTTPDataResponse) async throws -> HTTPDataResponse {
        try await self.middleware.handle(response) { response, data in
            return (response, data)
        }
    }
}

private struct Handler: HTTPResponseHandler {
    let middleware: any HTTPResponseMiddlewareProtocol
    let next: @Sendable (HTTPDataResponse) async throws -> HTTPDataResponse

    @Sendable func handle(_ response: HTTPDataResponse) async throws -> HTTPDataResponse {
        return try await self.middleware.handle(response) { response, data in
            try await self.next((response, data))
        }
    }
}
