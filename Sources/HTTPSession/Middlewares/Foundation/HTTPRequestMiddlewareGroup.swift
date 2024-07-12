import HTTPTypes

public actor HTTPRequestMiddlewareGroup: Sendable {
    private var middlewares: [any HTTPRequestMiddlewareProtocol]

    init(middlewares: [any HTTPRequestMiddlewareProtocol]) {
        self.middlewares = middlewares
    }

    /// Adds the provided middleware to the beginning of the middleware chain.
    public func add(_ middleware: any HTTPRequestMiddlewareProtocol) {
        self.middlewares.append(middleware)
    }

    func handle(_ request: inout HTTPRequest) async throws {
        for i in (0..<self.middlewares.count).reversed() {
            try await self.middlewares[i].handle(&request)
        }
    }
}
