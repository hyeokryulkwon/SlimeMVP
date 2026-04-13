import SwiftUI
import Combine

struct MainHomeView: View {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var vm: MVPViewModel
    @State private var liveNow = Date()
    @State private var isAutoPipelineRunning = false

    private let liveTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var creatureName: String {
        CharacterCatalog.names[vm.currentCharacter.characterId] ?? "알"
    }

    private var creatureID: String {
        vm.currentCharacter.characterId
    }

    private var creatureStageLabel: String {
        "Stage \(vm.currentCharacter.stage.rawValue)"
    }

    private var creatureAssetName: String? {
        CharacterCatalog.imageName(for: vm.currentCharacter.characterId)
    }

    private var effectiveElapsedMinutes: Int {
        let deltaSeconds = liveNow.timeIntervalSince(vm.currentCharacter.lastTickAt)
        let liveDeltaMinutes = max(0, Int(deltaSeconds / 60.0))
        return vm.currentCharacter.elapsedMinutes + liveDeltaMinutes
    }

    private var effectiveTotalElapsedMinutes: Int {
        let deltaSeconds = liveNow.timeIntervalSince(vm.currentCharacter.lastTickAt)
        let liveDeltaMinutes = max(0, Int(deltaSeconds / 60.0))
        return vm.currentCharacter.totalElapsedMinutes + liveDeltaMinutes
    }

    private var totalDayCount: Int {
        max(1, effectiveTotalElapsedMinutes / (24 * 60) + 1)
    }

    private var currentStageRequiredMinutes: Int {
        StageTimerEngine.requiredMinutes(for: vm.currentCharacter.stage) ?? 0
    }

    private var effectiveRemainingMinutes: Int {
        guard currentStageRequiredMinutes > 0 else { return 0 }
        return max(0, currentStageRequiredMinutes - effectiveElapsedMinutes)
    }

    private var stageProgressSummary: String {
        if currentStageRequiredMinutes == 0 {
            return "최종 단계"
        }
        return "현재 스테이지 \(effectiveElapsedMinutes)/\(currentStageRequiredMinutes)분 · 성장까지 \(effectiveRemainingMinutes)분 남음"
    }

    private var growthProgress: Double {
        guard currentStageRequiredMinutes > 0 else {
            return 1.0
        }
        return min(1.0, Double(effectiveElapsedMinutes) / Double(currentStageRequiredMinutes))
    }

    var body: some View {
        ZStack {
            // Dark background
            Color(red: 0.08, green: 0.08, blue: 0.12)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    // MARK: - Hero Section
                    VStack(spacing: 0) {
                        // MARK: - Top Status Area
                        VStack(spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(totalDayCount)일차")
                                        .font(.system(size: 28, weight: .bold))
                                        .foregroundColor(.white)
                                    
                                    Text(stageProgressSummary)
                                        .font(.system(size: 12, weight: .regular))
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            
                            // Progress bar
                            ProgressBarView(progress: growthProgress)
                                .frame(height: 6)
                                .padding(.horizontal, 20)
                        }
                        .padding(.bottom, 16)
                    
                        // MARK: - Character Section
                        VStack(spacing: 12) {
                            // Creature name, ID, stage
                            VStack(spacing: 4) {
                                Text(creatureName)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Text(creatureID)
                                    .font(.system(size: 11, weight: .regular))
                                    .foregroundColor(.gray)
                                
                                Text(creatureStageLabel)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Color(red: 0.65, green: 0.85, blue: 0.95))
                            }
                            .padding(.top, 16)
                            
                            // Animated creature - centered and prominent
                            ZStack {
                                // Soft background circle
                                Circle()
                                    .fill(Color(red: 0.12, green: 0.12, blue: 0.16))
                                    .frame(width: 200, height: 200)
                                
                                AnimatedCreatureView(assetName: creatureAssetName, size: CGSize(width: 160, height: 160))
                            }
                            .frame(height: 220)
                            .padding(.vertical, 8)
                            
                            Spacer()
                        }
                        .frame(maxHeight: 320)
                        
                        // MARK: - Bottom Action Area
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                ActionButton(icon: "fork.knife", label: "먹이기") {
                                    vm.incrementPetCount()
                                    Task { await vm.runPipeline() }
                                }
                                ActionButton(icon: "gamecontroller.fill", label: "놀기") {
                                    vm.incrementPlayCount()
                                    Task { await vm.runPipeline() }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 16)
                            
                            // Debug section - kept for development
                            VStack(alignment: .leading, spacing: 8) {
                                Text("📊 DEBUG INFO")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.gray)
                                
                                Text(vm.healthDebugSummary)
                                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                                    .foregroundColor(Color(red: 0.4, green: 0.8, blue: 0.4))
                                    .lineLimit(6)

                                Divider()
                                    .background(Color.white.opacity(0.15))

                                Text(vm.runtimeDebugSummary)
                                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                                    .foregroundColor(Color(red: 0.8, green: 0.8, blue: 0.9))
                                    .lineLimit(6)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color(red: 0.06, green: 0.06, blue: 0.1))
                            .cornerRadius(8)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 16)
                        }
                    }
                    
                    // MARK: - Admin/Debug Panel Section
                    VStack(spacing: 16) {
                        // Header
                        Text("🛠️ MVP Control Panel")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                        
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
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
            .task {
                await vm.runPipeline()
            }
            .onReceive(liveTimer) { now in
                liveNow = now
                guard currentStageRequiredMinutes > 0 else { return }
                guard effectiveRemainingMinutes == 0 else {
                    isAutoPipelineRunning = false
                    return
                }
                guard !isAutoPipelineRunning else { return }
                isAutoPipelineRunning = true
                Task {
                    await vm.runPipeline()
                    isAutoPipelineRunning = false
                }
            }
            .onChange(of: scenePhase) { _, newValue in
                guard newValue == .active else { return }
                liveNow = Date()
                isAutoPipelineRunning = false
                Task { await vm.runPipeline() }
            }
        }
    }
}

// MARK: - Subcomponents

struct ProgressBarView: View {
    let progress: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(red: 0.15, green: 0.15, blue: 0.2))
                
                // Progress fill
                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 1.0, green: 0.6, blue: 0.2),
                                Color(red: 1.0, green: 0.4, blue: 0.1)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * progress)
            }
        }
    }
}

struct ActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.9, green: 0.5, blue: 0.3),
                        Color(red: 0.8, green: 0.4, blue: 0.2)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(14)
            .shadow(color: Color(red: 0.8, green: 0.4, blue: 0.2).opacity(0.3), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MainHomeView(vm: MVPViewModel())
}
