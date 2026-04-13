import SwiftUI

// MARK: - Reusable Admin UI Components

struct AdminSectionView<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.gray)
                .textCase(.uppercase)
            
            VStack(spacing: 12) {
                content
            }
            .padding(12)
            .background(Color(red: 0.12, green: 0.12, blue: 0.16))
            .cornerRadius(10)
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: Any
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.gray)
            Spacer()
            Text(String(describing: value))
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundColor(Color(red: 0.4, green: 0.8, blue: 0.4))
        }
    }
}

struct MockMetricControl: View {
    let label: String
    let value: String
    let decrementLabel: String
    let incrementLabel: String
    let onDecrement: () -> Void
    let onIncrement: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text("\(label): \(value)")
                .font(.system(size: 11, weight: .semibold))
            Spacer()
            Button(decrementLabel, action: onDecrement)
                .adminButton()
            Button(incrementLabel, action: onIncrement)
                .adminButton()
        }
    }
}

extension View {
    func adminButton() -> some View {
        self
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(red: 0.2, green: 0.2, blue: 0.25))
            .foregroundColor(.white)
            .cornerRadius(6)
    }
}
