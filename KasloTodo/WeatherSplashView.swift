import SwiftUI

/// Weather splash screen that displays on app launch and dismisses on tap
struct WeatherSplashView: View {
    @ObservedObject var store: TodoStore
    @State private var weather: WeatherResponse?
    @State private var isLoading = true
    @Binding var isPresented: Bool
    
    init(store: TodoStore, isPresented: Binding<Bool>) {
        self.store = store
        self._isPresented = isPresented
        
        // Load cached weather immediately for instant display
        if let data = UserDefaults.standard.data(forKey: "cachedWeather"),
           let cached = try? JSONDecoder().decode(WeatherResponse.self, from: data) {
            _weather = State(initialValue: cached)
            _isLoading = State(initialValue: false)
        }
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: weatherGradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Weather content
            VStack(spacing: 24) {
                Spacer()
                
                if let weather = weather {
                    weatherDisplay(weather)
                } else if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                } else {
                    Text("Weather unavailable")
                        .foregroundStyle(.white.opacity(0.8))
                }
                
                Spacer()
                
                // Tap to continue hint
                VStack(spacing: 8) {
                    Image(systemName: "hand.tap.fill")
                        .font(.title2)
                    Text("Tap anywhere to continue")
                        .font(.subheadline)
                }
                .foregroundStyle(.white.opacity(0.6))
                .padding(.bottom, 40)
            }
            .padding()
        }
        .onTapGesture {
            withAnimation(.easeOut(duration: 0.3)) {
                isPresented = false
            }
        }
        .task {
            await loadWeather()
        }
    }
    
    // MARK: - Weather Display
    
    @ViewBuilder
    private func weatherDisplay(_ weather: WeatherResponse) -> some View {
        VStack(spacing: 32) {
            // Location
            Text("Kaslo, BC")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
            
            // Temperature
            if let temp = weather.obs?.temp {
                Text("\(Int(temp.rounded()))°")
                    .font(.system(size: 92, weight: .thin))
                    .foregroundStyle(.white)
            }
            
            // Conditions summary
            HStack(spacing: 32) {
                if let humidity = weather.obs?.humidity {
                    VStack(spacing: 4) {
                        Image(systemName: "humidity.fill")
                            .font(.title3)
                        Text("\(humidity)%")
                            .font(.headline)
                        Text("Humidity")
                            .font(.caption)
                    }
                    .foregroundStyle(.white.opacity(0.9))
                }
                
                if let wind = weather.obs?.windSpeedKmh {
                    VStack(spacing: 4) {
                        Image(systemName: "wind")
                            .font(.title3)
                        Text("\(Int(wind)) km/h")
                            .font(.headline)
                        Text("Wind")
                            .font(.caption)
                    }
                    .foregroundStyle(.white.opacity(0.9))
                }
                
                if let precip = weather.obs?.precip24hMm, precip > 0 {
                    VStack(spacing: 4) {
                        Image(systemName: "cloud.rain.fill")
                            .font(.title3)
                        Text(String(format: "%.1f mm", precip))
                            .font(.headline)
                        Text("Rain (24h)")
                            .font(.caption)
                    }
                    .foregroundStyle(.white.opacity(0.9))
                }
            }
            
            // Sun/Moon indicator
            if let isDaytime = weather.sun.isDaytime {
                HStack(spacing: 12) {
                    Text(isDaytime ? "☀️" : "🌙")
                        .font(.title)
                    
                    if isDaytime {
                        if let sunrise = weather.sun.sunrise {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Sunrise")
                                    .font(.caption)
                                Text(formatTime(sunrise))
                                    .font(.subheadline.weight(.medium))
                            }
                        }
                        if let sunset = weather.sun.sunset {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Sunset")
                                    .font(.caption)
                                Text(formatTime(sunset))
                                    .font(.subheadline.weight(.medium))
                            }
                        }
                    } else {
                        if let moonName = weather.moon.name {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(moonName)
                                    .font(.subheadline.weight(.medium))
                                if let illumination = weather.moon.illumination {
                                    Text("\(Int(illumination * 100))% illuminated")
                                        .font(.caption)
                                }
                            }
                        }
                    }
                }
                .foregroundStyle(.white.opacity(0.9))
                .padding(.top, 8)
            }
        }
    }
    
    // MARK: - Gradient Colors
    
    private var weatherGradient: [Color] {
        guard let weather = weather else {
            return [Color.blue, Color.blue.opacity(0.7)]
        }
        
        // Change gradient based on time of day
        if weather.sun.isDaytime == true {
            // Daytime gradient
            return [Color.blue, Color.cyan, Color.blue.opacity(0.8)]
        } else {
            // Nighttime gradient
            return [Color.indigo, Color.purple.opacity(0.8), Color.blue.opacity(0.6)]
        }
    }
    
    // MARK: - Data Loading
    
    private func loadWeather() async {
        // Only fetch if we don't have cached data
        guard weather == nil else {
            // Still fetch in background to update cache
            await fetchAndCacheWeather()
            return
        }
        
        await fetchAndCacheWeather()
        isLoading = false
    }
    
    private func fetchAndCacheWeather() async {
        do {
            let fetchedWeather = try await fetchWeather(serverURL: store.serverURL, apiKey: store.apiKey)
            weather = fetchedWeather
            
            // Cache the weather data
            if let data = try? JSONEncoder().encode(fetchedWeather) {
                UserDefaults.standard.set(data, forKey: "cachedWeather")
            }
        } catch {
            // Silently fail - we'll show cached data if available
            print("Weather fetch error: \(error.localizedDescription)")
        }
    }
    
    private func fetchWeather(serverURL: String, apiKey: String) async throws -> WeatherResponse {
        guard let baseURL = URL(string: serverURL) else {
            throw URLError(.badURL)
        }
        
        let weatherURL = baseURL.appendingPathComponent("weather-api.php")
        
        guard var components = URLComponents(url: weatherURL, resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }
        
        components.queryItems = [URLQueryItem(name: "api_key", value: apiKey)]
        
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.httpError(httpResponse.statusCode, nil)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(WeatherResponse.self, from: data)
    }
    
    // MARK: - Helpers
    
    private func formatTime(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: isoString) else { return isoString }
        
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        timeFormatter.timeZone = TimeZone(identifier: "America/Vancouver")
        return timeFormatter.string(from: date)
    }
}
