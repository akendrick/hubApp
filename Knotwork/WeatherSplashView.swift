import SwiftUI

/// Weather splash screen with 24-hour solar dial, moon phase, and date ring
struct WeatherSplashView: View {
    @ObservedObject var store: TodoStore
    @State private var weather: WeatherResponse?
    @State private var currentTime = Date()
    @Binding var isPresented: Bool
    
    // Timer to update the clock
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    init(store: TodoStore, isPresented: Binding<Bool>) {
        self.store = store
        self._isPresented = isPresented
        
        // Load cached weather immediately for instant display
        if let data = UserDefaults.standard.data(forKey: "cachedWeather"),
           let cached = try? JSONDecoder().decode(WeatherResponse.self, from: data) {
            _weather = State(initialValue: cached)
        }
    }
    
    var body: some View {
        ZStack {
            // Pure black background
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Location
                Text("KNOTWORK")
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                    .tracking(3)
                    .foregroundStyle(.white.opacity(0.6))
                
                // 24-hour Solar Dial with Date Ring
                solarDial
                
                // Current time display
                Text(currentTime, style: .time)
                    .font(.system(size: 24, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)

                Spacer()
                
                // Tap to continue hint
                VStack(spacing: 8) {
                    Image(systemName: "hand.tap.fill")
                        .font(.title3)
                    Text("Tap aywhere to continue")
                        .font(.caption)
                }
                .foregroundStyle(.white.opacity(0.4))
                .padding(.bottom, 40)
            }
        }
        .onTapGesture {
            withAnimation(.easeOut(duration: 0.3)) {
                isPresented = false
            }
        }
        .onReceive(timer) { time in
            currentTime = time
        }
        .task {
            await loadWeather()
        }
    }
    
    // MARK: - 24-Hour Solar Dial

    private var solarDial: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            
            ZStack {
                // Outer circle - day/night gradient background
                Circle()
                    .fill(Color(red: 0.05, green: 0.08, blue: 0.2))
                    .frame(width: size * 0.85, height: size * 0.85)

                // Astronomical twilight (outermost twilight range)
                TimeSectorShape(
                    startHour: sunriseHour - twilightTotalHours,
                    endHour: sunsetHour + twilightTotalHours
                )
                .fill(Color(red: 0.10, green: 0.20, blue: 0.42))
                .frame(width: size * 0.85, height: size * 0.85)

                // Nautical twilight
                TimeSectorShape(
                    startHour: sunriseHour - (civilTwilightHours + nauticalTwilightHours),
                    endHour: sunsetHour + (civilTwilightHours + nauticalTwilightHours)
                )
                .fill(Color(red: 0.16, green: 0.30, blue: 0.55))
                .frame(width: size * 0.85, height: size * 0.85)

                // Civil twilight (closest to daylight)
                TimeSectorShape(
                    startHour: sunriseHour - civilTwilightHours,
                    endHour: sunsetHour + civilTwilightHours
                )
                .fill(Color(red: 0.24, green: 0.44, blue: 0.72))
                .frame(width: size * 0.85, height: size * 0.85)

                DaylightSectorShape(sunriseHour: sunriseHour, sunsetHour: sunsetHour)
                    .fill(Color(red: 1.0, green: 0.95, blue: 0.3))
                    .frame(width: size * 0.85, height: size * 0.85)

                // Current date (inside dial, daylight half)
                Text(todayMonthLabel())
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.46, green: 0.83, blue: 1.2)) // Custom colour
                    .position(x: center.x, y: center.y - (size * 0.12))

                // Sun position indicator (behind hour labels)
                sunIndicator(hour: currentHourInKaslo, center: center, radius: size * 0.30)

                // Hour labels (all 24 hours)
                ForEach(0..<24, id: \.self) { hour in
                    hourLabel(hour: hour, center: center, radius: size * 0.385)
                }

                // Moon position indicator (outside the dial)
                moonIndicator(emoji: weather?.moon.emoji ?? "🌑", center: center, radius: size * 0.4)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(40)
    }
    
    // MARK: - Dial Components
    
    private func hourLabel(hour: Int, center: CGPoint, radius: CGFloat) -> some View {
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
            // Sun glow
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
            
            // Sun
            Circle()
                .fill(Color.white)
                .frame(width: 20, height: 20)
                .overlay(
                    Circle()
                        .stroke(Color.orange.opacity(0.7), lineWidth: 1.1)
                )
                .shadow(color: .white.opacity(0.95), radius: 12)
        }
        .position(
            x: center.x + radius * CGFloat(cos(adjustedAngle * .pi / 180)),
            y: center.y + radius * CGFloat(sin(adjustedAngle * .pi / 180))
        )
    }
    
    // MARK: - Moon Indicator
    
    private func moonIndicator(emoji: String, center: CGPoint, radius: CGFloat) -> some View {
        return ZStack {
            // Moon glow (subtle)
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
            
            // Moon emoji
            Text(emoji)
                .font(.system(size: 60))
        }
        .position(
            x: center.x,
            y: center.y + (radius * 0.5)
        )
    }

    private var sunriseHour: Double {
        // Try to parse the sunrise time string
        if let sunriseStr = weather?.sun.sunrise, !sunriseStr.isEmpty {
            if let hour = hourInKaslo(from: sunriseStr) {
                return hour
            }
        }
        
        // Fallback: calculate from daylight duration
        if let daylightMinutes = weather?.sun.daylightMinutes {
            let halfDay = Double(daylightMinutes) / 120.0
            return 12.0 - halfDay
        }
        
        // Last resort: default to 6:00 AM
        return 6.0
    }

    private var sunsetHour: Double {
        // Try to parse the sunset time string
        if let sunsetStr = weather?.sun.sunset, !sunsetStr.isEmpty {
            if let hour = hourInKaslo(from: sunsetStr) {
                return hour
            }
        }
        
        // Fallback: calculate from daylight duration
        if let daylightMinutes = weather?.sun.daylightMinutes {
            let halfDay = Double(daylightMinutes) / 120.0
            return 12.0 + halfDay
        }
        
        // Last resort: default to 6:00 PM
        return 18.0
    }

    private var currentHourInKaslo: Double {
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
        // Fixed orientation:
        // 06:00 = left, 12:00 = top, 18:00 = right, 00:00 = bottom
        (hour - 12.0) * 15.0 - 90.0
    }

    // Approximate twilight durations on each side of sunrise/sunset.
    // These can be replaced with API-provided times later if available.
    private var civilTwilightHours: Double { 0.5 }
    private var nauticalTwilightHours: Double { 0.5 }
    private var astronomicalTwilightHours: Double { 0.5 }
    private var twilightTotalHours: Double {
        civilTwilightHours + nauticalTwilightHours + astronomicalTwilightHours
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

    private func todayMonthLabel() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        formatter.timeZone = TimeZone(identifier: "America/Vancouver")
        return formatter.string(from: currentTime)
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
    
    // MARK: - Data Loading
    
    private func loadWeather() async {
        await fetchAndCacheWeather()
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
}

private struct TimeSectorShape: Shape {
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

private struct DaylightSectorShape: Shape {
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
