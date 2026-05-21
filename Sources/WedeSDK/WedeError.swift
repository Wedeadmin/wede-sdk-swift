import Foundation

public enum WedeError: Error, LocalizedError {
    case authError(String)
    case networkError(String)
    case apiError(String, Int)
    case validationError(String)

    public var errorDescription: String? {
        switch self {
        case .authError(let msg): return msg
        case .networkError(let msg): return msg
        case .apiError(let msg, _): return msg
        case .validationError(let msg): return msg
        }
    }
}
