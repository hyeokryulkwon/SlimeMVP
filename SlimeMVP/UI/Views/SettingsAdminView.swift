import SwiftUI

struct SettingsAdminView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var vm = MVPViewModel()
    @State private var isExpanded = false
    
    var body: some View {
        ZStack {
            // Dark background
            Color(red: 0.08, green: 0.08, blue: 0.12)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // MARK: - Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("⚙️ Settings & Admin")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                        Text("MVP Development Tools")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.gray)
                    }
                }
                .padding(20)
                
                ScrollView {
                    VStack(spacing: 16) {
                        // MARK: - App Controls Section
                        AdminSectionView(title: "🎮 App Controls") {
                            VStack(spacing: 12) {
                                Picker("Data Mode", selection: $vm.mode) {
                                    ForEach(DataSourceMode.allCases) { mode in
                                        Text(mode.rawValue).tag(mode)
                                    }
                                }
                                .pickerStyle(.segmented)
                                
                                HStack {
                                    Text("Health Status:")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.gray)
                                    Text(vm.permission.rawValue)
                                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                                        .foregroundColor(Color(red: 0.4, green: 0.8, blue: 0.4))
                                    
                                    Spacer()
                                    
                                    Button("Request") {
                                        Task { await vm.requestHealthPermission() }
                                    }
                                    .font(.system(size: 11, weight: .semibold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color(red: 0.9, green: 0.5, blue: 0.3))
                                    .foregroundColor(.white)
                                    .cornerRadius(6)
                                }
                                
                                Picker("Speed", selection: $vm.speedMultiplier) {
                                    Text("1x").tag(1)
                                    Text("60x").tag(60)
                                    Text("1440x").tag(1440)
                                }
                                .pickerStyle(.segmented)

                                if vm.mode == .mock {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text("Mock Input")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.gray)

                                        MockMetricControl(
                                            label: "moveKcal",
                                            value: Int(vm.mockMoveKcal).description,
                                            decrementLabel: "-100",
                                            incrementLabel: "+100",
                                            onDecrement: { vm.adjustMockMoveKcal(by: -100) },
                                            onIncrement: { vm.adjustMockMoveKcal(by: 100) }
                                        )

                                        MockMetricControl(
                                            label: "steps",
                                            value: Int(vm.mockSteps).description,
                                            decrementLabel: "-1000",
                                            incrementLabel: "+1000",
                                            onDecrement: { vm.adjustMockSteps(by: -1000) },
                                            onIncrement: { vm.adjustMockSteps(by: 1000) }
                                        )

                                        MockMetricControl(
                                            label: "sleepMinutes",
                                            value: vm.mockSleepMinutes.description,
                                            decrementLabel: "-60",
                                            incrementLabel: "+60",
                                            onDecrement: { vm.adjustMockSleepMinutes(by: -60) },
                                            onIncrement: { vm.adjustMockSleepMinutes(by: 60) }
                                        )
                                    }
                                }

                                HStack(spacing: 8) {
                                    Button("Run Pipeline") {
                                        Task { await vm.runPipeline() }
                                    }
                                    .font(.system(size: 11, weight: .semibold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color(red: 0.2, green: 0.45, blue: 0.7))
                                    .foregroundColor(.white)
                                    .cornerRadius(6)

                                    Button("Reset") {
                                        vm.resetProgress()
                                    }
                                    .font(.system(size: 11, weight: .semibold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color(red: 0.55, green: 0.18, blue: 0.18))
                                    .foregroundColor(.white)
                                    .cornerRadius(6)

                                    Spacer()
                                }

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Time Tick")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.gray)

                                    HStack(spacing: 8) {
                                        Button("+1min") { vm.tick(minutes: 1) }
                                            .adminButton()
                                        Button("+5min") { vm.tick(minutes: 5) }
                                            .adminButton()
                                        Button("+1day") { vm.tick(minutes: 1440) }
                                            .adminButton()
                                    }
                                }
                            }
                        }
                        
                        // MARK: - Character Data Section
                        AdminSectionView(title: "📊 Character Data") {
                            VStack(alignment: .leading, spacing: 8) {
                                InfoRow(label: "ID", value: vm.currentCharacter.characterId)
                                InfoRow(label: "Name", value: CharacterCatalog.names[vm.currentCharacter.characterId] ?? "Unknown")
                                InfoRow(label: "Stage", value: String(vm.currentCharacter.stage.rawValue))
                                InfoRow(label: "StageElapsed", value: "\(vm.currentCharacter.elapsedMinutes) min")
                                InfoRow(label: "TotalElapsed", value: "\(vm.currentCharacter.totalElapsedMinutes) min")
                                InfoRow(label: "StageRemaining", value: "\(vm.remainingMinutes) min")
                            }
                        }
                        
                        // MARK: - Daily Input Data
                        if let output = vm.output {
                            AdminSectionView(title: "📈 Daily Input Data") {
                                VStack(alignment: .leading, spacing: 8) {
                                    InfoRow(label: "moveKcal", value: Int(output.daily.moveKcal).description)
                                    InfoRow(label: "steps", value: Int(output.daily.steps).description)
                                    InfoRow(label: "play/pet", value: "\(output.daily.playCount) / \(output.daily.petCount)")
                                    InfoRow(label: "completeness", value: String(describing: output.daily.completeness))
                                }
                            }
                            
                            AdminSectionView(title: "🎯 Status Categories") {
                                VStack(alignment: .leading, spacing: 8) {
                                    InfoRow(label: "Weight", value: output.snapshot.weight.rawValue)
                                    InfoRow(label: "Sleep", value: output.snapshot.sleep.rawValue)
                                    InfoRow(label: "Happiness", value: output.snapshot.happiness.rawValue)
                                }
                            }
                            
                            AdminSectionView(title: "🔍 Judgment Trace") {
                                VStack(alignment: .leading, spacing: 8) {
                                    InfoRow(label: "usedFallback", value: output.trace.sleep.usedFallback ? "true" : "false")
                                    InfoRow(label: "sleepMinutes", value: output.trace.sleep.sleepMinutes.description)
                                    InfoRow(label: "weightActivityGap", value: String(format: "%.3f", output.trace.weightActivityGap))
                                    InfoRow(label: "happinessPoint", value: output.trace.happinessPoint.description)
                                    InfoRow(label: "evolutionReason", value: output.trace.evolutionReason)
                                }
                            }
                        }
                        
                        // MARK: - Errors
                        if let error = vm.lastError {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("⚠️ Last Error")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                                Text(error)
                                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                                    .foregroundColor(Color(red: 1.0, green: 0.6, blue: 0.6))
                            }
                            .padding(12)
                            .background(Color(red: 0.3, green: 0.08, blue: 0.08))
                            .cornerRadius(10)
                        }
                    }
                    .padding(20)
                }
            }
        }
    }
}

#Preview {
    SettingsAdminView()
}
