import Testing
import UIKit
@testable import WaiGoals

@Suite("Goal emotion")
struct GoalEmotionTests {
    @Test("An explicitly chosen emotion round-trips through SwiftData storage")
    func explicitEmotionRoundTrips() {
        let goal = Goal(title: "Deep work", emotion: .focus)

        #expect(goal.emotionRawValue == GoalEmotion.focus.rawValue)
        #expect(goal.emotion == .focus)

        goal.emotion = .calm
        #expect(goal.emotionRawValue == GoalEmotion.calm.rawValue)
        #expect(goal.emotion == .calm)
    }

    @Test("A legacy goal stays unassigned instead of receiving an invented emotion")
    func legacyGoalRemainsUnassigned() {
        let goal = Goal(title: "Existing goal")

        #expect(goal.emotionRawValue == nil)
        #expect(goal.emotion == nil)
    }

    @Test("Unknown persisted values are surfaced as unassigned")
    func unknownValueIsNotSilentlyReplaced() {
        let goal = Goal(title: "Imported goal")
        goal.emotionRawValue = "wonder"

        #expect(goal.emotion == nil)
    }

    @Test("Every emotion maps to a unique artwork asset")
    func artworkAssetsAreUnique() {
        let names = GoalEmotion.allCases.map(\.assetName)

        #expect(Set(names).count == GoalEmotion.allCases.count)
        #expect(names.allSatisfy { $0.hasPrefix("Emotion") })
    }

    @Test("Every emotional artwork is compiled into the app")
    @MainActor
    func artworkAssetsLoad() {
        for emotion in GoalEmotion.allCases {
            #expect(UIImage(named: emotion.assetName) != nil)
        }
    }
}
