import Foundation
enum AppFailure: Error {
    case message(String)
    case provider(String, String)
}
enum InsertionMode: String, CaseIterable, Identifiable {
    case paste, typing, copy
    var id: String { rawValue }
}
