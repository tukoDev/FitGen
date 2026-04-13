import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            ProgramView()
                .tabItem {
                    Label("Program", systemImage: "calendar.badge.checkmark")
                }

            ChatView()
                .tabItem {
                    Label("AI Coach", systemImage: "bubble.left.and.bubble.right.fill")
                }

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
        }
        .tint(.green)
    }
}
