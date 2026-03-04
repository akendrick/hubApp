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
/// Main tab view with Tasks and Weather
struct MainTabView: View {
    @ObservedObject var store: TodoStore
    
    var body: some View {
        TabView {
            ContentView(store: store)
                .tabItem {
                    Label("Tasks", systemImage: "checklist")
                }
            
            WeatherView(store: store)
                .tabItem {
                    Label("Weather", systemImage: "cloud.sun.fill")
                }
        }
    }
}

