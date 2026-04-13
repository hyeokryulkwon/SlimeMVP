import SwiftUI

struct AnimatedCreatureView: View {
    // Floating animation
    @State private var floatOffset: CGFloat = 0
    @State private var isFloatingUp = true
    
    // Rotation animation
    @State private var rotationAngle: Double = 0
    
    // Squash and stretch
    @State private var squashScale: CGFloat = 1.0
    @State private var stretchScale: CGFloat = 1.0
    
    // Jump animation
    @State private var jumpOffset: CGFloat = 0
    @State private var nextJumpTimer: Timer?
    @State private var jumpInterval: Double = Double.random(in: 4...8)
    
    // Tap reaction
    @State private var tapScale: CGFloat = 1.0
    @State private var isPressed = false
    
    // Character image name (customize this with your PNG asset name)
    let assetName: String?
    let size: CGSize
    
    init(assetName: String? = "slime_sl_01_01", size: CGSize = CGSize(width: 120, height: 120)) {
        self.assetName = assetName
        self.size = size
    }
    
    var body: some View {
        ZStack {
            if let assetName, UIImage(named: assetName) != nil {
                Image(assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size.width, height: size.height)
                    .scaleEffect(x: squashScale, y: stretchScale, anchor: .center)
                    .rotationEffect(.degrees(rotationAngle))
                    .offset(y: floatOffset + jumpOffset)
                    .scaleEffect(tapScale)
                    .opacity(0.9)
            } else {
                // Graceful placeholder when asset is missing
                VStack(spacing: 8) {
                    Image(systemName: "questionmark.square.dashed")
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(Color.white.opacity(0.8))
                        .frame(width: size.width * 0.5, height: size.height * 0.5)

                    Text("이미지 준비중")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                }
                .frame(width: size.width, height: size.height)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color(red: 0.14, green: 0.14, blue: 0.18))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
                .scaleEffect(tapScale)
                .offset(y: floatOffset + jumpOffset)
            }
        }
        .onAppear {
            startAnimations()
        }
        .onDisappear {
            stopAnimations()
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.05)
                .onChanged { _ in
                    handleTapBegan()
                }
                .onEnded { _ in
                    handleTapEnded()
                }
        )
    }
    
    private func startAnimations() {
        // Start floating animation
        startFloating()
        
        // Start subtle rotation
        startRotation()
        
        // Start squash and stretch
        startSquashStretch()
        
        // Start random jump timer
        scheduleNextJump()
    }
    
    private func stopAnimations() {
        nextJumpTimer?.invalidate()
        nextJumpTimer = nil
    }
    
    private func startFloating() {
        withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
            floatOffset = 15
        }
    }
    
    private func startRotation() {
        withAnimation(.linear(duration: 4).repeatForever(autoreverses: true)) {
            rotationAngle = 3
        }
    }
    
    private func startSquashStretch() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            performSquashStretch()
        }
    }
    
    private func performSquashStretch() {
        // Squash down
        withAnimation(.easeInOut(duration: 0.4)) {
            squashScale = 0.95
            stretchScale = 1.05
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            // Stretch back
            withAnimation(.easeInOut(duration: 0.4)) {
                squashScale = 1.0
                stretchScale = 1.0
            }
            
            // Repeat in 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                performSquashStretch()
            }
        }
    }
    
    private func scheduleNextJump() {
        nextJumpTimer?.invalidate()
        nextJumpTimer = Timer.scheduledTimer(withTimeInterval: jumpInterval, repeats: false) { _ in
            performJump()
            jumpInterval = Double.random(in: 4...8)
            scheduleNextJump()
        }
    }
    
    private func performJump() {
        // Jump up
        withAnimation(.easeOut(duration: 0.3)) {
            jumpOffset = -25
        }
        
        // Fall down with bounce
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeIn(duration: 0.3)) {
                jumpOffset = 0
            }
        }
    }
    
    private func handleTapBegan() {
        isPressed = true
        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
            tapScale = 0.85
        }
    }
    
    private func handleTapEnded() {
        isPressed = false
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            tapScale = 1.0
        }
        
        // Trigger a jump when tapped
        performJump()
    }
}

#Preview {
    VStack {
        Spacer()
        AnimatedCreatureView()
            .frame(maxWidth: .infinity)
        Spacer()
        Text("Tap to interact!")
            .foregroundColor(.gray)
            .padding()
    }
    .background(Color(.systemGray6))
}
