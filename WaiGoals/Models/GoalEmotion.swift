import Foundation

/// The inner state a person wants to practice through a goal.
///
/// Unlike the goal's accent color or SF Symbol, this is part of the goal's
/// meaning. Persist the raw value explicitly so existing stores can remain
/// unassigned until a person makes a deliberate choice.
enum GoalEmotion: String, CaseIterable, Identifiable, Hashable, Sendable {
    case focus
    case calm
    case courage
    case energy
    case joy
    case connection
    case growth
    case balance

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .focus: "Focus"
        case .calm: "Calm"
        case .courage: "Courage"
        case .energy: "Energy"
        case .joy: "Joy"
        case .connection: "Connection"
        case .growth: "Growth"
        case .balance: "Balance"
        }
    }

    var feeling: String {
        switch self {
        case .focus: "Clear & absorbed"
        case .calm: "Quiet & steady"
        case .courage: "Brave & capable"
        case .energy: "Alive & ready"
        case .joy: "Light & delighted"
        case .connection: "Close & supported"
        case .growth: "Expanding & capable"
        case .balance: "Centered & whole"
        }
    }

    var completionMessage: String {
        switch self {
        case .focus: "You made space for clarity."
        case .calm: "You returned to steadiness."
        case .courage: "You chose the brave step."
        case .energy: "You created momentum."
        case .joy: "You made room for delight."
        case .connection: "You moved closer."
        case .growth: "You became a little more."
        case .balance: "You restored the center."
        }
    }

    var assetName: String {
        "Emotion\(displayName)"
    }
}
