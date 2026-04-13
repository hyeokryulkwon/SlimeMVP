import SwiftUI

struct EvolutionLogView: View {
    @ObservedObject var vm: MVPViewModel

    private let pageBackground = Color(red: 0.08, green: 0.08, blue: 0.12)

    private var currentPreview: (name: String, stage: Stage, reason: String)? {
        guard let output = vm.output,
              let preview = EvolutionEngine.previewNext(current: vm.currentCharacter, snapshot: output.snapshot) else {
            return nil
        }
        return (CharacterCatalog.names[preview.id] ?? preview.id, preview.stage, preview.reason)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                pageBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        if let currentPreview {
                            CurrentPreviewCard(
                                currentCharacterId: vm.currentCharacter.characterId,
                                previewName: currentPreview.name,
                                previewStage: currentPreview.stage,
                                previewReason: currentPreview.reason
                            )
                        }

                        if vm.evolutionLogs.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 32, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.8))

                                Text("진화 로그가 아직 없습니다")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)

                                Text("진화가 발생하면 어떤 데이터와 조건으로 결과가 바뀌었는지 여기에 기록됩니다.")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 32)
                            }
                            .padding(.top, 40)
                        } else {
                            ForEach(vm.evolutionLogs) { entry in
                                EvolutionLogCard(entry: entry)
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("진화 로그")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !vm.evolutionLogs.isEmpty {
                        Button("Clear") {
                            vm.clearEvolutionLogs()
                        }
                        .foregroundColor(.white)
                    }
                }
            }
        }
    }
}

private struct CurrentPreviewCard: View {
    let currentCharacterId: String
    let previewName: String
    let previewStage: Stage
    let previewReason: String

    private var currentName: String {
        CharacterCatalog.names[currentCharacterId] ?? currentCharacterId
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("현재 예상")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.gray)

            Text("\(currentName) → \(previewName)")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)

            Text("다음 단계: Stage \(previewStage.rawValue)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(red: 0.75, green: 0.83, blue: 0.95))

            Text(previewReason)
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundColor(Color(red: 0.45, green: 0.85, blue: 0.55))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(red: 0.18, green: 0.12, blue: 0.1))
        .cornerRadius(14)
    }
}

private struct EvolutionLogCard: View {
    let entry: EvolutionLogEntry

    private var timestampText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: entry.evolvedAt)
    }

    private var fromName: String {
        CharacterCatalog.names[entry.fromCharacterId] ?? entry.fromCharacterId
    }

    private var toName: String {
        CharacterCatalog.names[entry.toCharacterId] ?? entry.toCharacterId
    }

    private var nextPreview: (name: String, stage: Stage, reason: String)? {
        let current = CharacterState(
            characterId: entry.toCharacterId,
            stage: entry.toStage,
            parentId: entry.fromCharacterId,
            enteredAt: entry.evolvedAt,
            elapsedMinutes: 0,
            totalElapsedMinutes: 0,
            lastTickAt: entry.evolvedAt
        )
        let snapshot = CategorySnapshot(weight: entry.weight, sleep: entry.sleep, happiness: entry.happiness)
        guard let preview = EvolutionEngine.previewNext(current: current, snapshot: snapshot) else {
            return nil
        }
        return (CharacterCatalog.names[preview.id] ?? preview.id, preview.stage, preview.reason)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(fromName) → \(toName)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)

                    Text("Stage \(entry.fromStage.rawValue) → Stage \(entry.toStage.rawValue)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(red: 0.75, green: 0.83, blue: 0.95))
                }

                Spacer()

                Text(timestampText)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundColor(.gray)
            }

            Divider()
                .background(Color.white.opacity(0.15))

            VStack(alignment: .leading, spacing: 6) {
                logRow("결과", toName)
                logRow("판정 이유", entry.reason)
                logRow("데이터 모드", entry.dataSource.rawValue)
                logRow("진화 체크", "\(entry.elapsedMinutesAtCheck) / \(entry.requiredMinutes) min")
                if let nextPreview {
                    logRow("다음 예상", "\(nextPreview.name) (Stage \(nextPreview.stage.rawValue))")
                    logRow("예상 기준", nextPreview.reason)
                }
            }

            Divider()
                .background(Color.white.opacity(0.15))

            VStack(alignment: .leading, spacing: 6) {
                Text("입력 데이터")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.gray)

                logRow("moveKcal", Int(entry.moveKcal).description)
                logRow("steps", Int(entry.steps).description)
                logRow("sleepMinutes", entry.sleepMinutes.description)
                logRow("play / pet", "\(entry.playCount) / \(entry.petCount)")
            }

            Divider()
                .background(Color.white.opacity(0.15))

            VStack(alignment: .leading, spacing: 6) {
                Text("카테고리 판정")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.gray)

                logRow("weight", categoryLabel(for: entry.weight))
                logRow("sleep", categoryLabel(for: entry.sleep))
                logRow("happiness", categoryLabel(for: entry.happiness))
            }
        }
        .padding(14)
        .background(Color(red: 0.12, green: 0.12, blue: 0.16))
        .cornerRadius(14)
    }

    private func logRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.gray)
                .frame(width: 88, alignment: .leading)

            Text(value)
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundColor(Color(red: 0.45, green: 0.85, blue: 0.55))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func categoryLabel(for value: WeightCategory) -> String {
        switch value {
        case .veryLean: return "-2 veryLean"
        case .lean: return "-1 lean"
        case .normal: return "0 normal"
        case .overweight: return "1 overweight"
        case .obese: return "2 obese"
        }
    }

    private func categoryLabel(for value: SleepCategory) -> String {
        switch value {
        case .low: return "-1 low"
        case .normal: return "0 normal"
        case .high: return "1 high"
        }
    }

    private func categoryLabel(for value: HappinessCategory) -> String {
        switch value {
        case .low: return "-1 low"
        case .normal: return "0 normal"
        case .high: return "1 high"
        }
    }
}

#Preview {
    EvolutionLogView(vm: MVPViewModel())
}
