import Foundation

enum EvolutionEngine {
    static func evolve(current: CharacterState, snapshot: CategorySnapshot, now: Date) -> EvolutionResult {
        switch current.stage {
        case .stage0:
            return EvolutionResult(
                next: CharacterState(characterId: "SL-01-01", stage: .stage1, parentId: "SL-00-01", enteredAt: now, elapsedMinutes: 0, totalElapsedMinutes: current.totalElapsedMinutes, lastTickAt: now),
                reason: "Stage0 5분 경과: 단일 루트"
            )
        case .stage1:
            let next = evolveStage1To2(snapshot: snapshot)
            return EvolutionResult(
                next: CharacterState(characterId: next.id, stage: .stage2, parentId: current.characterId, enteredAt: now, elapsedMinutes: 0, totalElapsedMinutes: current.totalElapsedMinutes, lastTickAt: now),
                reason: next.reason
            )
        case .stage2:
            let next = evolveStage2To3(parent: current.characterId, snapshot: snapshot)
            return EvolutionResult(
                next: CharacterState(characterId: next.id, stage: .stage3, parentId: current.characterId, enteredAt: now, elapsedMinutes: 0, totalElapsedMinutes: current.totalElapsedMinutes, lastTickAt: now),
                reason: next.reason
            )
        case .stage3:
            return EvolutionResult(next: current, reason: "Stage3 최종 단계")
        }
    }

    static func previewNext(current: CharacterState, snapshot: CategorySnapshot) -> (id: String, stage: Stage, reason: String)? {
        switch current.stage {
        case .stage0:
            return ("SL-01-01", .stage1, "Stage0 5분 경과: 단일 루트")
        case .stage1:
            let next = evolveStage1To2(snapshot: snapshot)
            return (next.id, .stage2, next.reason)
        case .stage2:
            let next = evolveStage2To3(parent: current.characterId, snapshot: snapshot)
            return (next.id, .stage3, next.reason)
        case .stage3:
            return nil
        }
    }

    private static func evolveStage1To2(snapshot: CategorySnapshot) -> (id: String, reason: String) {
        let inRange = [-1, 0, 1].contains(snapshot.weight.rawValue)

        if inRange && snapshot.sleep == .normal && snapshot.happiness == .normal {
            return ("SL-02-01", "W{-1~+1}, S0, H0")
        }
        if inRange && snapshot.sleep == .normal && snapshot.happiness == .high {
            return ("SL-02-02", "W{-1~+1}, S0, H+1")
        }
        if inRange && (snapshot.sleep != .normal || snapshot.happiness == .low) {
            return ("SL-02-03", "W{-1~+1}, (S!=0 or H=-1)")
        }
        return ("SL-02-04", "예외/잔여 루트")
    }

    private static func evolveStage2To3(parent: String, snapshot: CategorySnapshot) -> (id: String, reason: String) {
        let inRange = [-1, 0, 1].contains(snapshot.weight.rawValue)

        switch parent {
        case "SL-02-01":
            if !inRange { return ("SL-03-08", "weight out of range") }
            if snapshot.weight == .normal && snapshot.sleep == .normal && snapshot.happiness == .high {
                return ("SL-03-04", "W0,S0,H+1")
            }
            if snapshot.sleep == .normal && snapshot.happiness == .normal {
                return ("SL-03-01", "S0,H0")
            }
            if snapshot.sleep == .low && snapshot.happiness == .normal {
                return ("SL-03-02", "S-1,H0")
            }
            if snapshot.sleep == .high || snapshot.happiness == .high {
                return ("SL-03-03", "S+1 or H+1")
            }
            return ("SL-03-08", "fallback")

        case "SL-02-02":
            if !inRange { return ("SL-03-08", "weight out of range") }
            if snapshot.sleep == .high {
                return ("SL-03-06", "S+1 우선")
            }
            if snapshot.sleep == .normal && snapshot.happiness == .high {
                return ("SL-03-05", "S0,H+1")
            }
            return ("SL-03-08", "fallback")

        case "SL-02-03":
            if !inRange { return ("SL-03-08", "weight out of range") }
            if snapshot.sleep != .normal || snapshot.happiness == .low {
                return ("SL-03-07", "S!=0 or H=-1")
            }
            return ("SL-03-08", "fallback")

        case "SL-02-04":
            return ("SL-03-08", "틈새 루트 강제 수렴")

        default:
            return ("SL-03-08", "unknown parent fallback")
        }
    }
}
