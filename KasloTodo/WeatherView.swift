import SwiftUI

struct WeatherView: View {
    @ObservedObject var store: TodoStore
    @State private var weather: WeatherResponse?
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if isLoading && weather == nil {
                        ProgressView("Loading weather...")
                            .frame(maxWidth: .infinity, maxHeight: 300)
                    } else if let error = errorMessage {
                        errorView(error)
                    } else if let weather = weather {
                        weatherContent(weather)
                    } else {
                        emptyView
                    }
                }
                .padding()
            }
            .navigationTitle("Kaslo Weather")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await loadWeather()
            }
        }
        .task {
            await loadWeather()
        }
    }
    
    // MARK: - Weather Content
    
    @ViewBuilder
    private func weatherContent(_ weather: WeatherResponse) -> some View {
        // Current Conditions Card
        if let obs = weather.obs {
            currentConditionsCard(obs)
        }
        
        // Sun & Moon Card
        sunMoonCard(sun: weather.sun, moon: weather.moon)
        
        // Indoor Conditions (if available)
        if let obs = weather.obs, obs.indoorTemp != nil || obs.indoorHumidity != nil {
            indoorConditionsCard(obs)
        }
        
        // Forecast
        forecastSection(weather.forecast)
        
        // Metadata
        metadataFooter(weather.meta)
    }
    
    // MARK: - Current Conditions Card
    
    private func currentConditionsCard(_ obs: WeatherObservation) -> some View {
        VStack(spacing: 16) {
            // Main Temperature
            if let temp = obs.temp {
                VStack(spacing: 4) {
                    Text("\(Int(temp.rounded()))°")
                        .font(.system(size: 72, weight: .thin))
                    if let feelsLike = obs.feelsLike, abs(feelsLike - temp) > 1 {
                        Text("Feels like \(Int(feelsLike.rounded()))°")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Divider()
            
            // Weather Details Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                if let humidity = obs.humidity {
                    weatherDetail(icon: "humidity.fill", label: "Humidity", value: "\(humidity)%")
                }
                if let dewPoint = obs.dewPoint {
                    weatherDetail(icon: "drop.fill", label: "Dew Point", value: "\(Int(dewPoint.rounded()))°C")
                }
                if let pressure = obs.pressureHpa {
                    weatherDetail(icon: "gauge.with.dots.needle.bottom.50percent", label: "Pressure", value: "\(Int(pressure.rounded())) hPa")
                }
                if let wind = obs.windSpeedKmh {
                    let windText = obs.windGustKmh != nil ? "\(Int(wind)) / \(Int(obs.windGustKmh!)) km/h" : "\(Int(wind)) km/h"
                    weatherDetail(icon: "wind", label: "Wind", value: windText)
                }
                if let precip24h = obs.precip24hMm {
                    weatherDetail(icon: "cloud.rain.fill", label: "24h Rain", value: String(format: "%.1f mm", precip24h))
                }
                if let uv = obs.uvIndex {
                    weatherDetail(icon: "sun.max.fill", label: "UV Index", value: String(format: "%.1f", uv))
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func weatherDetail(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.medium))
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Sun & Moon Card
    
    private func sunMoonCard(sun: SunPosition, moon: MoonPhase) -> some View {
        VStack(spacing: 16) {
            // Sun Position Dial
            if let angle = sun.nowAngle, let isDaytime = sun.isDaytime {
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .stroke(Color.blue.opacity(0.2), lineWidth: 3)
                            .frame(width: 120, height: 120)
                        
                        Circle()
                            .fill(isDaytime ? Color.yellow : Color.blue.opacity(0.3))
                            .frame(width: 20, height: 20)
                            .offset(y: -50)
                            .rotationEffect(.degrees(angle))
                        
                        Text(isDaytime ? "☀️" : "🌙")
                            .font(.title)
                    }
                    
                    if let sunrise = sun.sunrise, let sunset = sun.sunset {
                        HStack(spacing: 20) {
                            VStack(spacing: 2) {
                                Text("Sunrise")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(formatTime(sunrise))
                                    .font(.subheadline.weight(.medium))
                            }
                            VStack(spacing: 2) {
                                Text("Sunset")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(formatTime(sunset))
                                    .font(.subheadline.weight(.medium))
                            }
                        }
                    }
                    
                    if let daylight = sun.daylightMinutes {
                        Text("\(daylight / 60)h \(daylight % 60)m of daylight")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Divider()
            
            // Moon Phase
            if let moonEmoji = moon.emoji, let moonName = moon.name {
                VStack(spacing: 8) {
                    Text(moonEmoji)
                        .font(.system(size: 60))
                    Text(moonName)
                        .font(.headline)
                    if let illumination = moon.illumination {
                        Text("\(Int(illumination * 100))% illuminated")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Indoor Conditions Card
    
    private func indoorConditionsCard(_ obs: WeatherObservation) -> some View {
        VStack(spacing: 12) {
            Label("Indoor Conditions", systemImage: "house.fill")
                .font(.headline)
            
            HStack(spacing: 40) {
                if let temp = obs.indoorTemp {
                    VStack(spacing: 4) {
                        Text("\(Int(temp.rounded()))°C")
                            .font(.title2.weight(.semibold))
                        Text("Temperature")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if let humidity = obs.indoorHumidity {
                    VStack(spacing: 4) {
                        Text("\(humidity)%")
                            .font(.title2.weight(.semibold))
                        Text("Humidity")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Forecast Section
    
    private func forecastSection(_ forecast: [DailyForecast]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("16-Day Forecast")
                .font(.headline)
                .padding(.horizontal, 4)
            
            ForEach(forecast.prefix(16)) { day in
                forecastRow(day)
            }
        }
    }
    
    private func forecastRow(_ day: DailyForecast) -> some View {
        HStack(spacing: 12) {
            // Date
            VStack(alignment: .leading, spacing: 2) {
                Text(formatDate(day.date))
                    .font(.subheadline.weight(.medium))
                if day.date == todayString() {
                    Text("Today")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }
            }
            .frame(width: 80, alignment: .leading)
            
            // Icon
            if let icon = day.icon {
                Text(icon)
                    .font(.title3)
                    .frame(width: 40)
            }
            
            Spacer()
            
            // Precipitation
            if let precipProb = day.precipProbPct, precipProb > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "drop.fill")
                        .font(.caption)
                        .foregroundStyle(.blue)
                    Text("\(precipProb)%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 50)
            }
            
            // Temps
            HStack(spacing: 8) {
                if let hi = day.hi {
                    Text("\(Int(hi.rounded()))°")
                        .font(.subheadline.weight(.semibold))
                }
                if let lo = day.lo {
                    Text("\(Int(lo.rounded()))°")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 60, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Metadata Footer
    
    private func metadataFooter(_ meta: WeatherMeta) -> some View {
        VStack(spacing: 4) {
            if let generated = meta.generated {
                Text("Updated \(formatRelativeTime(generated))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Text("Kaslo, BC (49.912°N, 116.908°W)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }
    
    // MARK: - Empty & Error States
    
    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "cloud.sun.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)
            Text("No weather data")
                .font(.headline)
            Button("Load Weather") {
                Task { await loadWeather() }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxHeight: 300)
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.orange)
            Text("Error loading weather")
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task { await loadWeather() }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxHeight: 300)
        .padding()
    }
    
    // MARK: - Data Loading
    
    private func loadWeather() async {
        isLoading = true
        errorMessage = nil
        
        do {
            weather = try await fetchWeather(serverURL: store.serverURL, apiKey: store.apiKey)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
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
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else { return dateString }
        
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "EEE, MMM d"
        return outputFormatter.string(from: date)
    }
    
    private func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    private func formatRelativeTime(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: isoString) else { return isoString }
        return date.formatted(.relative(presentation: .named))
    }
}

// MARK: - Preview

#Preview {
    WeatherView(store: TodoStore())
}
