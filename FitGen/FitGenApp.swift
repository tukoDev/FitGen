import SwiftUI

@main
struct FitGenApp: App {
    init() {
        ExerciseImageLoader.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
