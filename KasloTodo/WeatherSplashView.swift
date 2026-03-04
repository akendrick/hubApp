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
                Text("KASLO")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
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
                    Text("Tap to continue")
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
                // Outer date ring (days of month)
                dateRing(center: center, radius: size * 0.46)
                
                // Outer circle - day/night gradient background
                Circle()
                    .fill(
                        AngularGradient(
                            gradient: Gradient(colors: dayNightGradient),
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360)
                        )
                    )
                    .frame(width: size * 0.85, height: size * 0.85)
                
                // 24-hour markers
                ForEach(0..<24) { hour in
                    hourMarker(hour: hour, center: center, radius: size * 0.38)
                }
                
                // Hour labels (every 2 hours)
                ForEach(Array(stride(from: 0, to: 24, by: 2)), id: \.self) { hour in
                    hourLabel(hour: hour, center: center, radius: size * 0.32)
                }
                
                // Sun position indicator
                if let sunAngle = weather?.sun.nowAngle {
                    sunIndicator(angle: sunAngle, center: center, radius: size * 0.35)
                }
                
                // Moon position indicator (outside the dial)
                if let moonPhase = weather?.moon.phase {
                    moonIndicator(phase: moonPhase, center: center, radius: size * 0.35)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(40)
    }
    
    // MARK: - Dial Components
    
    private var dayNightGradient: [Color] {
        // Simple gradient: Top half = yellow (day), bottom half = dark blue (night)
        // This is FIXED and never rotates
        return [
            // Top hemisphere - Day
            Color(red: 1.0, green: 0.95, blue: 0.3),   // Yellow (top)
            Color(red: 1.0, green: 0.95, blue: 0.3),   // Yellow
            Color(red: 1.0, green: 0.95, blue: 0.3),   // Yellow
            Color(red: 1.0, green: 0.95, blue: 0.3),   // Yellow
            
            // Horizon transition (left and right sides at 6am/6pm)
            Color(red: 0.5, green: 0.6, blue: 0.8),    // Transition
            
            // Bottom hemisphere - Night
            Color(red: 0.05, green: 0.08, blue: 0.2),  // Dark blue (bottom)
            Color(red: 0.05, green: 0.08, blue: 0.2),  // Dark blue
            Color(red: 0.05, green: 0.08, blue: 0.2),  // Dark blue
            Color(red: 0.05, green: 0.08, blue: 0.2),  // Dark blue
            
            // Other side transition
            Color(red: 0.5, green: 0.6, blue: 0.8),    // Transition
            
            // Back to top
            Color(red: 1.0, green: 0.95, blue: 0.3),   // Yellow
        ]
    }
    
    // MARK: - Date Ring
    
    private func dateRing(center: CGPoint, radius: CGFloat) -> some View {
        let calendar = Calendar.current
        let today = calendar.component(.day, from: currentTime)
        let daysInMonth = calendar.range(of: .day, in: .month, for: currentTime)?.count ?? 31
        
        // Calculate rotation offset to put current day at 12 o'clock (top)
        let degreesPerDay = 360.0 / Double(daysInMonth)
        let rotationOffset = -Double(today - 1) * degreesPerDay - 180.0 // Adjusted for new orientation
        
        return ForEach(1...daysInMonth, id: \.self) { day in
            let angle = Double(day - 1) * degreesPerDay + rotationOffset
            let isToday = day == today
            
            Text("\(day)")
                .font(.system(size: isToday ? 14 : 10, weight: isToday ? .bold : .regular, design: .rounded))
                .foregroundStyle(isToday ? Color.white : Color.white.opacity(0.5))
                .position(
                    x: center.x + radius * CGFloat(cos(angle * .pi / 180)),
                    y: center.y + radius * CGFloat(sin(angle * .pi / 180))
                )
        }
    }
    
    private func hourMarker(hour: Int, center: CGPoint, radius: CGFloat) -> some View {
        // Adjust angle: hour 12 at top (0°), hour 0/24 at bottom (180°)
        let angle = Double(hour) * 15.0 - 180.0 // 360/24 = 15 degrees per hour, offset by 180
        let markerLength: CGFloat = hour % 6 == 0 ? 20 : (hour % 3 == 0 ? 15 : 10)
        let markerWidth: CGFloat = hour % 6 == 0 ? 2 : 1
        
        return Rectangle()
            .fill(Color.white.opacity(hour % 6 == 0 ? 0.8 : 0.5))
            .frame(width: markerWidth, height: markerLength)
            .position(
                x: center.x + radius * CGFloat(cos(angle * .pi / 180)),
                y: center.y + radius * CGFloat(sin(angle * .pi / 180))
            )
            .rotationEffect(.degrees(angle + 90), anchor: .center)
    }
    
    private func hourLabel(hour: Int, center: CGPoint, radius: CGFloat) -> some View {
        // Adjust angle: hour 12 at top (0°), hour 0/24 at bottom (180°)
        let angle = Double(hour) * 15.0 - 180.0
        let displayHour = hour == 0 ? 24 : hour
        
        return Text("\(displayHour)")
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.9))
            .position(
                x: center.x + radius * CGFloat(cos(angle * .pi / 180)),
                y: center.y + radius * CGFloat(sin(angle * .pi / 180))
            )
    }
    
    private func sunIndicator(angle: Double, center: CGPoint, radius: CGFloat) -> some View {
        // Convert sun angle (0-360, midnight=0, noon=180) to dial position
        // On our dial: noon=0° (top), midnight=180° (bottom)
        // So we need to subtract 180 from the sun angle
        let adjustedAngle = angle - 180.0
        
        return ZStack {
            // Sun glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.yellow.opacity(0.6), Color.yellow.opacity(0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 25
                    )
                )
                .frame(width: 50, height: 50)
            
            // Sun
            Circle()
                .fill(Color.yellow)
                .frame(width: 20, height: 20)
                .shadow(color: .yellow.opacity(0.8), radius: 10)
        }
        .position(
            x: center.x + radius * CGFloat(cos(adjustedAngle * .pi / 180)),
            y: center.y + radius * CGFloat(sin(adjustedAngle * .pi / 180))
        )
    }
    
    // MARK: - Moon Indicator
    
    private func moonIndicator(phase: Double, center: CGPoint, radius: CGFloat) -> some View {
        // Moon is stationary at the bottom center (midnight position)
        // Position: 180° (bottom of dial)
        let moonAngle = 0.0 // 0° = bottom in our coordinate system (after -180 adjustment)
        
        // Get moon emoji
        let moonEmoji = weather?.moon.emoji ?? "🌑"
        
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
            Text(moonEmoji)
                .font(.system(size: 30))
        }
        .position(
            x: center.x + 0, // No horizontal offset - centered
            y: center.y + radius // At the bottom
        )
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
