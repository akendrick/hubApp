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
            ContentView(store: store)
        } else {
            OnboardingView(store: store)
        }
    }
}
