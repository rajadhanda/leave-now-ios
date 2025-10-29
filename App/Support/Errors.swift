import Foundation

enum AppError: Error, LocalizedError {
    case network(String)
    case decoding
    case permissions
    case unavailable(String)

    var errorDescription: String? {
        switch self {
        case .network(let message):
            return message
        case .decoding:
            return "Data parsing failed."
        case .permissions:
            return "Required permission not granted."
        case .unavailable(let what):
            return "\(what) is currently unavailable."
        }
    }
}
