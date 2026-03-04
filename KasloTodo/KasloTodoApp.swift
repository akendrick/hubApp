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
    @State private var showWeatherSplash = true

    var body: some View {
        ZStack {
            // Main app content
            if store.isConfigured {
                MainTabView(store: store)
            } else {
                OnboardingView(store: store)
            }
            
            // Weather splash overlay
            if showWeatherSplash && store.isConfigured {
                WeatherSplashView(store: store, isPresented: $showWeatherSplash)
                    .transition(.opacity)
                    .zIndex(1)
            }
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

