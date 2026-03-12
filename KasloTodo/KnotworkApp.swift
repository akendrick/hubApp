import SwiftUI

@main
struct KnotworkApp: App {
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
            if store.isConfigured {
                MainTabView(store: store)
            } else {
                OnboardingView(store: store)
            }

            if showWeatherSplash && store.isConfigured {
                WeatherSplashView(store: store, isPresented: $showWeatherSplash)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
    }
}

/// Main tab view — Tasks, Weather, Darkroom
struct MainTabView: View {
    @ObservedObject var store: TodoStore
    @StateObject private var darkroomStore: DarkroomStore

    init(store: TodoStore) {
        self.store = store
        _darkroomStore = StateObject(
            wrappedValue: DarkroomStore(serverURL: store.serverURL, apiKey: store.apiKey)
        )
    }

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

            DarkroomView(store: darkroomStore)
                .tabItem {
                    Label("Darkroom", systemImage: "camera.aperture")
                }
        }
    }
}
