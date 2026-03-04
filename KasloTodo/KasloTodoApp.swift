import SwiftUI

@main
struct KasloTodoApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

/// Shows onboarding until both serverURL and apiKey are set in the store.
struct RootView: View {
    @StateObject private var store = TodoStore()

    var body: some View {
        if store.isConfigured {
            MainTabView(store: store)
        } else {
            OnboardingView(store: store)
        }
    }
}
/// Main content view - just shows the tasks list
struct MainTabView: View {
    @ObservedObject var store: TodoStore
    
    var body: some View {
        ContentView(store: store)
    }
}

