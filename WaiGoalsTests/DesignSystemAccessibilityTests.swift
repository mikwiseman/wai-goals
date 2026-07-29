import Testing
@testable import WaiGoals

@Suite("Design system accessibility")
struct DesignSystemAccessibilityTests {
    @Test("Every accent foreground meets graphical contrast across both gradient stops")
    func gradientForegroundContrast() {
        for accent in AccentToken.allCases {
            #expect(
                accent.minimumGradientForegroundContrast >= 3,
                "\(accent.rawValue) falls below 3:1 contrast"
            )
        }
    }

    @Test("Lazy-row entrance delay is capped")
    func entranceDelayCap() {
        #expect(WaiMotion.entranceDelay(order: 2) == 0.11)
        #expect(WaiMotion.entranceDelay(order: 50) == 0.44)
        #expect(WaiMotion.entranceDelay(order: -1) == 0)
    }
}
