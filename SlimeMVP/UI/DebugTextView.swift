import SwiftUI

struct DebugTextView: View {
    @StateObject private var vm = MVPViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    GroupBox("실행 설정") {
                        VStack(alignment: .leading, spacing: 10) {
                            Picker("Data Mode", selection: $vm.mode) {
                                ForEach(DataSourceMode.allCases) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)

                            HStack {
                                Text("권한 상태: \(vm.permission.rawValue)")
                                Button("Health 권한 요청") {
                                    Task { await vm.requestHealthPermission() }
                                }
                            }

                            Stepper("playCount: \(vm.playCount)", value: $vm.playCount, in: 0...20)
                            Stepper("petCount: \(vm.petCount)", value: $vm.petCount, in: 0...20)

                            Picker("속도", selection: $vm.speedMultiplier) {
                                Text("1x").tag(1)
                                Text("60x").tag(60)
                                Text("1440x").tag(1440)
                            }
                            .pickerStyle(.segmented)

                            HStack {
                                Button("+1분 Tick") { vm.tick(minutes: 1) }
                                Button("+5분 Tick") { vm.tick(minutes: 5) }
                                Button("+1일 Tick") { vm.tick(minutes: 1440) }
                            }

                            HStack {
                                Button("파이프라인 실행") { Task { await vm.runPipeline() } }
                            }
                        }
                    }

                        GroupBox("현재 캐릭터") {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("ID: \(vm.currentCharacter.characterId)")
                                Text("Name: \(CharacterCatalog.names[vm.currentCharacter.characterId] ?? "Unknown")")
                                Text("Stage: \(vm.currentCharacter.stage.rawValue)")
                                Text("StageElapsed: \(vm.currentCharacter.elapsedMinutes) min")
                                Text("TotalElapsed: \(vm.currentCharacter.totalElapsedMinutes) min")
                                Text("StageRemaining: \(vm.remainingMinutes) min")
                            }
                            .font(.system(.body, design: .monospaced))
                        }

                    if let output = vm.output {
                        GroupBox("입력 데이터") {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("moveKcal: \(Int(output.daily.moveKcal))")
                                Text("steps: \(Int(output.daily.steps))")
                                Text("play/pet: \(output.daily.playCount) / \(output.daily.petCount)")
                                Text("completeness: \(String(describing: output.daily.completeness))")
                            }
                            .font(.system(.caption, design: .monospaced))
                        }

                        GroupBox("카테고리") {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Weight: \(output.snapshot.weight.rawValue)")
                                Text("Sleep: \(output.snapshot.sleep.rawValue)")
                                Text("Happiness: \(output.snapshot.happiness.rawValue)")
                            }
                            .font(.system(.body, design: .monospaced))
                        }

                        GroupBox("판정 Trace") {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("usedFallback: \(output.trace.sleep.usedFallback ? "true" : "false")")
                                Text("sleepMinutes: \(output.trace.sleep.sleepMinutes)")
                                Text("weightActivityGap: \(String(format: "%.3f", output.trace.weightActivityGap))")
                                Text("happinessPoint: \(output.trace.happinessPoint)")
                                Text("evolutionReason: \(output.trace.evolutionReason)")
                            }
                            .font(.system(.caption, design: .monospaced))
                        }
                    }

                    if let error = vm.lastError {
                        Text(error).foregroundStyle(.red)
                    }
                }
                .padding()
            }
            .navigationTitle("Slime MVP (Text)")
        }
    }
}
