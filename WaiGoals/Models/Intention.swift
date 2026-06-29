import Foundation
import SwiftData

enum IntentionCue: String, CaseIterable, Identifiable {
    case morning
    case firstBreak
    case lunch
    case evening
    case beforeBed

    static let defaultCue: IntentionCue = .firstBreak

    var id: String { rawValue }

    var title: String {
        switch self {
        case .morning: return "Morning"
        case .firstBreak: return "First break"
        case .lunch: return "Lunch"
        case .evening: return "Evening"
        case .beforeBed: return "Before bed"
        }
    }

    var symbol: String {
        switch self {
        case .morning: return "sunrise.fill"
        case .firstBreak: return "cup.and.saucer.fill"
        case .lunch: return "fork.knife"
        case .evening: return "sunset.fill"
        case .beforeBed: return "bed.double.fill"
        }
    }

    private var trigger: String {
        switch self {
        case .morning: return "the morning starts"
        case .firstBreak: return "I take my first break"
        case .lunch: return "lunch ends"
        case .evening: return "the evening starts"
        case .beforeBed: return "I get ready for bed"
        }
    }

    func planLine(for goalTitle: String) -> String {
        "If \(trigger), then I’ll do this: \(goalTitle)."
    }
}

/// A daily commitment to act on a goal before it is completed. Intention and
/// completion stay separate so a morning pledge never changes progress stats.
@Model
final class Intention {
    var id: UUID = UUID()
    /// The day this intention belongs to, normalized to local start-of-day.
    var day: Date = Date.now
    /// `IntentionCue.rawValue`.
    var cueRaw: String = IntentionCue.defaultCue.rawValue
    var approvedAt: Date = Date.now
    var goal: Goal?

    init(
        id: UUID = UUID(),
        day: Date,
        cue: IntentionCue = .defaultCue,
        approvedAt: Date = .now,
        goal: Goal? = nil
    ) {
        self.id = id
        self.day = day
        self.cueRaw = cue.rawValue
        self.approvedAt = approvedAt
        self.goal = goal
    }

    var cue: IntentionCue {
        get {
            guard let cue = IntentionCue(rawValue: cueRaw) else {
                preconditionFailure("Invalid IntentionCue raw value: \(cueRaw)")
            }
            return cue
        }
        set { cueRaw = newValue.rawValue }
    }
}
