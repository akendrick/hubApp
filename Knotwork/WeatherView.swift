import SwiftUI

struct WeatherView: View {
    @ObservedObject var store: TodoStore
    @State private var weather: WeatherResponse?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var currentTime = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    // MARK: - Initialization
    
    init(store: TodoStore) {
        self.store = store
        // Load cached weather on init
        if let data = UserDefaults.standard.data(forKey: "cachedWeather"),
           let cached = try? JSONDecoder().decode(WeatherResponse.self, from: data) {
            _weather = State(initialValue: cached)
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 2) {
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
            .navigationTitle("Weather")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await loadWeather()
            }
        }
        .task {
            await loadWeather()
        }
        .onReceive(timer) { time in
            currentTime = time
        }
    }
    
    // MARK: - Weather Content
    
    @ViewBuilder
    private func weatherContent(_ weather: WeatherResponse) -> some View {
        Text(todayFullDateLabel())
            .font(.headline.weight(.semibold))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 0)

        // Section 1: Current temperatures + humidity
        if let obs = weather.obs {
            currentTemperaturesCard(obs)
        }

        // Sundial between the two sections
        sunMoonCard(weather)

        // Section 2: All other weather information
        if let obs = weather.obs {
            otherConditionsCard(obs)
        }
        
        // Forecast
        forecastSection(weather.forecast)
        
        // Metadata
        metadataFooter(weather.meta)
    }
    
    // MARK: - Current Conditions Card
    
    private func currentTemperaturesCard(_ obs: WeatherObservation) -> some View {
        HStack(alignment: .top, spacing: 20) {
            // Outdoor
            VStack(alignment: .leading, spacing: 6) {
                Text("Outdoor")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                if let temp = obs.temp {
                    Text("\(Int(temp.rounded()))°")
                        .font(.system(size: 64, weight: .thin))
                } else {
                    Text("--")
                        .font(.system(size: 64, weight: .thin))
                }

                if let humidity = obs.humidity {
                    Label("\(humidity)%", systemImage: "humidity.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            // Indoor (same API payload)
            VStack(alignment: .leading, spacing: 8) {
                Text("Indoor")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                if let indoorTemp = obs.indoorTemp {
                    Text("\(Int(indoorTemp.rounded()))°C")
                        .font(.system(size: 29, weight: .semibold))
                } else {
                    Text("--")
                        .font(.system(size: 29, weight: .semibold))
                }

                if let indoorHumidity = obs.indoorHumidity {
                    Label("\(indoorHumidity)%", systemImage: "humidity.fill")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(.secondary)
                } else {
                    Label("--", systemImage: "humidity.fill")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(uiColor: .tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .frame(minWidth: 130, alignment: .leading)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func otherConditionsCard(_ obs: WeatherObservation) -> some View {
        VStack(spacing: 18) {
            HStack(alignment: .top, spacing: 20) {
                VStack(spacing: 14) {
                    weatherDetail(
                        icon: "cloud.rain.fill",
                        label: "Now (Precip)",
                        value: obs.precipRateMmh.map { String(format: "%.1f mm/h", $0) } ?? "0.0 mm/h"
                    )
                    weatherDetail(
                        icon: "drop.fill",
                        label: "Prev 24h",
                        value: obs.precip24hMm.map { String(format: "%.1f mm", $0) } ?? "0.0 mm"
                    )
                    weatherDetail(
                        icon: "cloud.rain",
                        label: "Past Week",
                        value: obs.precip7dMm.map { String(format: "%.1f mm", $0) } ?? "0.0 mm"
                    )
                }
                .frame(maxWidth: .infinity, alignment: .top)

                VStack(spacing: 14) {
                    if let uv = obs.uvIndex {
                        weatherDetail(icon: "sun.max.fill", label: "UV Index", value: String(format: "%.1f", uv))
                    }
                    if let dewPoint = obs.dewPoint {
                        weatherDetail(icon: "drop.fill", label: "Dew Point", value: "\(Int(dewPoint.rounded()))°C")
                    }
                    if let wind = obs.windSpeedKmh {
                        let windText = obs.windGustKmh != nil ? "\(Int(wind)) / \(Int(obs.windGustKmh!)) km/h" : "\(Int(wind)) km/h"
                        weatherDetail(icon: "wind", label: "Wind", value: windText)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }

            if let pressure = obs.pressureHpa {
                weatherDetail(
                    icon: "gauge.with.dots.needle.bottom.50percent",
                    label: "Pressure",
                    value: "\(Int(pressure.rounded())) hPa"
                )
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
    
    private func sunMoonCard(_ weather: WeatherResponse) -> some View {
        let sunrise = resolvedSunriseHour(weather.sun)
        let sunset = resolvedSunsetHour(weather.sun)

        return VStack(spacing: 16) {
            GeometryReader { geometry in
                let size = min(geometry.size.width, geometry.size.height)
                let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)

                ZStack {
                    Circle()
                        .fill(Color(red: 0.05, green: 0.08, blue: 0.2))
                        .frame(width: size * 0.85, height: size * 0.85)

                    WeatherPageTimeSectorShape(
                        startHour: sunrise - twilightTotalHours,
                        endHour: sunset + twilightTotalHours
                    )
                    .fill(Color(red: 0.10, green: 0.20, blue: 0.42))
                    .frame(width: size * 0.85, height: size * 0.85)

                    WeatherPageTimeSectorShape(
                        startHour: sunrise - (civilTwilightHours + nauticalTwilightHours),
                        endHour: sunset + (civilTwilightHours + nauticalTwilightHours)
                    )
                    .fill(Color(red: 0.16, green: 0.30, blue: 0.55))
                    .frame(width: size * 0.85, height: size * 0.85)

                    WeatherPageTimeSectorShape(
                        startHour: sunrise - civilTwilightHours,
                        endHour: sunset + civilTwilightHours
                    )
                    .fill(Color(red: 0.24, green: 0.44, blue: 0.72))
                    .frame(width: size * 0.85, height: size * 0.85)

                    WeatherPageDaylightSectorShape(
                        sunriseHour: sunrise,
                        sunsetHour: sunset
                    )
                    .fill(Color(red: 1.0, green: 0.95, blue: 0.3))
                    .frame(width: size * 0.85, height: size * 0.85)

                    Text(todayMonthLabel())
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .position(x: center.x, y: center.y - (size * 0.12))

                    sunIndicator(hour: currentHourInKaslo(), center: center, radius: size * 0.30)

                    ForEach(0..<24, id: \.self) { hour in
                        hourLabel(hour: hour, center: center, radius: size * 0.385, sunriseHour: sunrise, sunsetHour: sunset)
                    }

                    moonIndicator(emoji: weather.moon.emoji ?? "🌑", center: center, radius: size * 0.35)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .padding(.horizontal, 2)

            HStack(spacing: 20) {
                VStack(spacing: 2) {
                    Text("Sunrise")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(formatHourValue(sunrise))
                        .font(.subheadline.weight(.medium))
                }
                VStack(spacing: 2) {
                    Text("Sunset")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(formatHourValue(sunset))
                        .font(.subheadline.weight(.medium))
                }
            }

            if let daylight = weather.sun.daylightMinutes {
                Text("\(daylight / 60)h \(daylight % 60)m of daylight")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let moonName = weather.moon.name {
                VStack(spacing: 8) {
                    Text(moonName)
                        .font(.headline)
                    if let illumination = weather.moon.illumination {
                        Text("\(Int(illumination * 100))% illuminated")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(1)
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
            // Cache the weather data
            if let data = try? JSONEncoder().encode(weather) {
                UserDefaults.standard.set(data, forKey: "cachedWeather")
            }
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
        let raw = isoString.trimmingCharacters(in: .whitespacesAndNewlines)
        let date: Date?
        if let parsed = parseISODate(raw) {
            date = parsed
        } else if let parsed = parseServerDateTime(raw) {
            date = parsed
        } else {
            date = nil
        }

        if let parts = parseClockTime(raw), date == nil {
            let h = Int(parts)
            let m = Int((parts - Double(h)) * 60.0)
            return String(format: "%02d:%02d", h, m)
        }

        guard let date else { return "--:--" }
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
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

    private func hourLabel(hour: Int, center: CGPoint, radius: CGFloat, sunriseHour: Double, sunsetHour: Double) -> some View {
        let angle = dialAngleDegrees(forHour: Double(hour))
        let displayHour = hour == 0 ? 24 : hour
        let daylight = isDaylightHour(Double(hour), sunrise: sunriseHour, sunset: sunsetHour)

        return Text("\(displayHour)")
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(daylight ? Color(red: 0.05, green: 0.15, blue: 0.35) : .white)
            .position(
                x: center.x + radius * CGFloat(cos(angle * .pi / 180)),
                y: center.y + radius * CGFloat(sin(angle * .pi / 180))
            )
    }

    private func sunIndicator(hour: Double, center: CGPoint, radius: CGFloat) -> some View {
        let adjustedAngle = dialAngleDegrees(forHour: hour)

        return ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.75), Color.white.opacity(0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 30
                    )
                )
                .frame(width: 56, height: 56)

            Circle()
                .fill(Color.white)
                .frame(width: 20, height: 20)
                .overlay(
                    Circle()
                        .stroke(Color.orange.opacity(0.7), lineWidth: 1.5)
                )
                .shadow(color: .white.opacity(0.95), radius: 12)
        }
        .position(
            x: center.x + radius * CGFloat(cos(adjustedAngle * .pi / 180)),
            y: center.y + radius * CGFloat(sin(adjustedAngle * .pi / 180))
        )
    }

    private func moonIndicator(emoji: String, center: CGPoint, radius: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.3), Color.white.opacity(0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 20
                    )
                )
                .frame(width: 40, height: 40)

            Text(emoji)
                .font(.system(size: 60))
        }
        .position(
            x: center.x,
            y: center.y + (radius * 0.5)
        )
    }

    private func currentHourInKaslo() -> Double {
        let calendar = Calendar(identifier: .gregorian)
        let timeZone = TimeZone(identifier: "America/Vancouver") ?? .current
        let components = calendar.dateComponents(in: timeZone, from: currentTime)
        let hour = Double(components.hour ?? 0)
        let minute = Double(components.minute ?? 0)
        let second = Double(components.second ?? 0)
        return hour + (minute / 60.0) + (second / 3600.0)
    }

    private func hourInKaslo(from isoString: String?) -> Double? {
        guard let isoString else { return nil }
        let value = isoString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Try parsing as ISO date first
        if let parsed = parseISODate(value) {
            return dateToKasloHour(parsed)
        }
        
        // Try parsing as server datetime format
        if let parsed = parseServerDateTime(value) {
            return dateToKasloHour(parsed)
        }
        
        // Try parsing as simple clock time (HH:MM or H:MM)
        if let localHour = parseClockTime(value) {
            return localHour
        }
        
        // Try parsing as decimal hour (e.g., "6.5" for 6:30)
        if let decimalHour = Double(value) {
            return decimalHour
        }
        
        return nil
    }
    private func dialAngleDegrees(forHour hour: Double) -> Double {
        (hour - 12.0) * 15.0 - 90.0
    }

    private func todayMonthLabel() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        formatter.timeZone = TimeZone(identifier: "America/Vancouver")
        return formatter.string(from: currentTime)
    }

    private func todayFullDateLabel() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMMM yyyy"
        formatter.timeZone = TimeZone(identifier: "America/Vancouver")
        return formatter.string(from: currentTime)
    }

    private var civilTwilightHours: Double { 0.5 }
    private var nauticalTwilightHours: Double { 0.5 }
    private var astronomicalTwilightHours: Double { 0.5 }
    private var twilightTotalHours: Double {
        civilTwilightHours + nauticalTwilightHours + astronomicalTwilightHours
    }

    private func resolvedSunriseHour(_ sun: SunPosition) -> Double {
        // Try to parse the sunrise time string
        if let sunriseStr = sun.sunrise, !sunriseStr.isEmpty {
            if let hour = hourInKaslo(from: sunriseStr) {
                return hour
            }
        }
        
        // Fallback: calculate from daylight duration
        if let daylightMinutes = sun.daylightMinutes {
            let halfDay = Double(daylightMinutes) / 120.0
            return 12.0 - halfDay
        }
        
        // Last resort: default to 6:00 AM
        return 6.0
    }
    private func resolvedSunsetHour(_ sun: SunPosition) -> Double {
        // Try to parse the sunset time string
        if let sunsetStr = sun.sunset, !sunsetStr.isEmpty {
            if let hour = hourInKaslo(from: sunsetStr) {
                return hour
            }
        }
        
        // Fallback: calculate from daylight duration
        if let daylightMinutes = sun.daylightMinutes {
            let halfDay = Double(daylightMinutes) / 120.0
            return 12.0 + halfDay
        }
        
        // Last resort: default to 6:00 PM
        return 18.0
    }
    private func isDaylightHour(_ hour: Double, sunrise: Double, sunset: Double) -> Bool {
        let h = normalizeHour(hour)
        let rise = normalizeHour(sunrise)
        let set = normalizeHour(sunset)
        if rise <= set {
            return h >= rise && h <= set
        } else {
            return h >= rise || h <= set
        }
    }

    private func normalizeHour(_ hour: Double) -> Double {
        var h = hour.truncatingRemainder(dividingBy: 24.0)
        if h < 0 { h += 24.0 }
        return h
    }

    private func parseISODate(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }

    private func parseServerDateTime(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "America/Vancouver")

        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let date = formatter.date(from: value) { return date }
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.date(from: value)
    }

    private func parseClockTime(_ value: String) -> Double? {
        let parts = value.split(separator: ":")
        guard parts.count >= 2 else { return nil }
        guard let hour = Int(parts[0]), let minute = Int(parts[1]) else { return nil }
        guard (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        
        // Also handle seconds if present
        let seconds = parts.count >= 3 ? (Int(parts[2]) ?? 0) : 0
        
        return Double(hour) + (Double(minute) / 60.0) + (Double(seconds) / 3600.0)
    }
    private func dateToKasloHour(_ date: Date) -> Double {
        let calendar = Calendar(identifier: .gregorian)
        let timeZone = TimeZone(identifier: "America/Vancouver") ?? .current
        let components = calendar.dateComponents(in: timeZone, from: date)
        let hour = Double(components.hour ?? 0)
        let minute = Double(components.minute ?? 0)
        return hour + (minute / 60.0)
    }

    private func formatHourValue(_ hour: Double) -> String {
        let normalized = normalizeHour(hour)
        let totalMinutes = Int((normalized * 60.0).rounded())
        let h = (totalMinutes / 60) % 24
        let m = totalMinutes % 60
        return String(format: "%02d:%02d", h, m)
    }
}

private struct WeatherPageTimeSectorShape: Shape {
    let startHour: Double
    let endHour: Double

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2.0
        let start = normalizeHour(startHour)
        let end = normalizeHour(endHour)
        let arcLength = normalizedArcLength(start: start, end: end)
        let samples = 180

        var path = Path()
        path.move(to: center)
        for i in 0...samples {
            let t = Double(i) / Double(samples)
            let hour = start + (arcLength * t)
            let wrappedHour = normalizeHour(hour)
            let angle = dialAngleDegrees(forHour: wrappedHour) * .pi / 180.0
            let point = CGPoint(
                x: center.x + radius * CGFloat(cos(angle)),
                y: center.y + radius * CGFloat(sin(angle))
            )
            path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }

    private func normalizeHour(_ hour: Double) -> Double {
        var h = hour.truncatingRemainder(dividingBy: 24.0)
        if h < 0 { h += 24.0 }
        return h
    }

    private func normalizedArcLength(start: Double, end: Double) -> Double {
        let length = end - start
        return length >= 0 ? length : length + 24.0
    }

    private func dialAngleDegrees(forHour hour: Double) -> Double {
        (hour - 12.0) * 15.0 - 90.0
    }
}

private struct WeatherPageDaylightSectorShape: Shape {
    let sunriseHour: Double
    let sunsetHour: Double

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2.0
        let sunrise = normalizeHour(sunriseHour)
        let sunset = normalizeHour(sunsetHour)
        let dayLength = normalizedDayLength(sunrise: sunrise, sunset: sunset)
        let samples = 180

        var path = Path()
        path.move(to: center)
        for i in 0...samples {
            let t = Double(i) / Double(samples)
            let hour = sunrise + (dayLength * t)
            let wrappedHour = normalizeHour(hour)
            let angle = dialAngleDegrees(forHour: wrappedHour) * .pi / 180.0
            let point = CGPoint(
                x: center.x + radius * CGFloat(cos(angle)),
                y: center.y + radius * CGFloat(sin(angle))
            )
            path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }

    private func normalizeHour(_ hour: Double) -> Double {
        var h = hour.truncatingRemainder(dividingBy: 24.0)
        if h < 0 { h += 24.0 }
        return h
    }

    private func normalizedDayLength(sunrise: Double, sunset: Double) -> Double {
        let length = sunset - sunrise
        return length >= 0 ? length : length + 24.0
    }

    private func dialAngleDegrees(forHour hour: Double) -> Double {
        (hour - 12.0) * 15.0 - 90.0
    }
}

// MARK: - Preview

#Preview {
    WeatherView(store: TodoStore())
}
