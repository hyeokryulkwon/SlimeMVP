import SwiftUI

struct RootTabView: View {
    @StateObject private var vm = MVPViewModel()

    var body: some View {
        TabView {
            MainHomeView(vm: vm)
                .tabItem {
                    Label("홈", systemImage: "house.fill")
                }

            EvolutionLogView(vm: vm)
                .tabItem {
                    Label("진화 로그", systemImage: "clock.arrow.circlepath")
                }
        }
        .tint(Color(red: 0.95, green: 0.55, blue: 0.25))
    }
}

#Preview {
    RootTabView()
}
