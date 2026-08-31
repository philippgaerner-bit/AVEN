import Foundation

// ─── API Environment ──────────────────────────────────────────────────────────
// Debug: StubAVENAPIClient (no network)
// Staging/Production: RealAVENAPIClient (Phase 7.2+)

enum APIEnvironment {
    case debug
    case staging
    case production

    static var current: APIEnvironment {
        #if DEBUG
        return .debug
        #elseif STAGING
        return .staging
        #else
        return .production
        #endif
    }

    var baseURL: URL {
        switch self {
        case .debug:
            return URL(string: "http://localhost:3000")!
        case .staging:
            return URL(string: "https://api-staging.aven.app")!
        case .production:
            return URL(string: "https://api.aven.app")!
        }
    }

    var useMockData: Bool {
        self == .debug
    }
}

// ─── Factory ──────────────────────────────────────────────────────────────────

extension AppContainer {
    static func makeAPIClient() -> AVENAPIClient {
        switch APIEnvironment.current {
        case .debug:
            return StubAVENAPIClient()
        case .staging, .production:
            // Phase 7.2: return RealAVENAPIClient(baseURL: APIEnvironment.current.baseURL)
            return StubAVENAPIClient() // temporary until real client is implemented
        }
    }
}
