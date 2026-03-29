import Foundation

enum StageTimerEngine {
    static let stage0Minutes = 5
    static let stage1Minutes = 24 * 60
    static let stage2Minutes = 2 * 24 * 60

    static func requiredMinutes(for stage: Stage) -> Int? {
        switch stage {
        case .stage0: return stage0Minutes
        case .stage1: return stage1Minutes
        case .stage2: return stage2Minutes
        case .stage3: return nil
        }
    }

    static func canEvolve(_ state: CharacterState) -> Bool {
        guard let req = requiredMinutes(for: state.stage) else { return false }
        return state.elapsedMinutes >= req
    }

    static func remainingMinutes(_ state: CharacterState) -> Int {
        guard let req = requiredMinutes(for: state.stage) else { return 0 }
        return max(0, req - state.elapsedMinutes)
    }
}
