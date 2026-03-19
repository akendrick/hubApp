import Foundation

// MARK: - Weather API Response

struct WeatherResponse: Codable {
    let obs: WeatherObservation?
    let forecast: [DailyForecast]
    let sun: SunPosition
    let moon: MoonPhase
    let meta: WeatherMeta
}

// MARK: - Current Observations

struct WeatherObservation: Codable {
    let temp: Double?
    let feelsLike: Double?
    let dewPoint: Double?
    let humidity: Int?
    let pressureHpa: Double?
    let windSpeedKmh: Double?
    let windDirection: Int?
    let windGustKmh: Double?
    let precipRateMmh: Double?
    let precip24hMm: Double?
    let precip7dMm: Double?
    let uvIndex: Double?
    let solarWm2: Double?
    let indoorTemp: Double?
    let indoorHumidity: Int?
    
    enum CodingKeys: String, CodingKey {
        case temp
        case feelsLike = "feels_like"
        case dewPoint = "dew_point"
        case humidity
        case pressureHpa = "pressure_hpa"
        case windSpeedKmh = "wind_speed_kmh"
        case windDirection = "wind_direction"
        case windGustKmh = "wind_gust_kmh"
        case precipRateMmh = "precip_rate_mmh"
        case precip24hMm = "precip_24h_mm"
        case precip7dMm = "precip_7d_mm"
        case uvIndex = "uv_index"
        case solarWm2 = "solar_wm2"
        case indoorTemp = "indoor_temp"
        case indoorHumidity = "indoor_humidity"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let raw = try decoder.container(keyedBy: AnyCodingKey.self)
        temp = c.decodeLossyDouble(forKey: .temp)
        feelsLike = c.decodeLossyDouble(forKey: .feelsLike)
        dewPoint = c.decodeLossyDouble(forKey: .dewPoint)
        humidity = c.decodeLossyInt(forKey: .humidity)
        pressureHpa = c.decodeLossyDouble(forKey: .pressureHpa)
        windSpeedKmh = c.decodeLossyDouble(forKey: .windSpeedKmh)
        windDirection = c.decodeLossyInt(forKey: .windDirection)
        windGustKmh = c.decodeLossyDouble(forKey: .windGustKmh)
        precipRateMmh = raw.decodeLossyDouble(forKeys: [
            "precip_rate_mmh",
            "precipRateMmh",
            "rain_rate_mmh",
            "rainRateMmh",
            "rainrate_mmh",
            "rain_rate",
            "rainRate",
            "rainrate",
            "rainratemm",
            "rainratein",
            "rrain_piezo",
            "piezo_rain_rate",
            "piezoRainRate"
        ])
        precip24hMm = raw.decodeLossyDouble(forKeys: [
            "precip_24h_mm",
            "precip24hMm",
            "rain_24h_mm",
            "rain24hMm",
            "dailyrainmm",
            "daily_rain_mm",
            "dailyRainMm",
            "dailyrainin"
        ])
        precip7dMm = raw.decodeLossyDouble(forKeys: [
            "precip_7d_mm",
            "precip7dMm",
            "rain_7d_mm",
            "rain7dMm",
            "weeklyrainmm",
            "weekly_rain_mm",
            "weeklyRainMm",
            "weeklyrainin"
        ])
        uvIndex = c.decodeLossyDouble(forKey: .uvIndex)
        solarWm2 = c.decodeLossyDouble(forKey: .solarWm2)
        indoorTemp = c.decodeLossyDouble(forKey: .indoorTemp)
        indoorHumidity = c.decodeLossyInt(forKey: .indoorHumidity)
    }
}

private struct AnyCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init(_ stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(stringValue: String) {
        self.init(stringValue)
    }

    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

private extension KeyedDecodingContainer where K == WeatherObservation.CodingKeys {
    func decodeLossyDouble(forKey key: K) -> Double? {
        if let d = try? decodeIfPresent(Double.self, forKey: key) { return d }
        if let i = try? decodeIfPresent(Int.self, forKey: key) { return Double(i) }
        if let s = try? decodeIfPresent(String.self, forKey: key) {
            return parseLossyDouble(s)
        }
        return nil
    }

    func decodeLossyInt(forKey key: K) -> Int? {
        if let i = try? decodeIfPresent(Int.self, forKey: key) { return i }
        if let d = try? decodeIfPresent(Double.self, forKey: key) { return Int(d.rounded()) }
        if let s = try? decodeIfPresent(String.self, forKey: key),
           let d = Double(s.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return Int(d.rounded())
        }
        return nil
    }
}

private extension KeyedDecodingContainer where K == AnyCodingKey {
    func decodeLossyDouble(forKeys keys: [String]) -> Double? {
        for keyString in keys {
            let key = AnyCodingKey(keyString)

            if let d = try? decodeIfPresent(Double.self, forKey: key) {
                return d
            }
            if let i = try? decodeIfPresent(Int.self, forKey: key) {
                return Double(i)
            }
            if let s = try? decodeIfPresent(String.self, forKey: key),
               let parsed = parseLossyDouble(s) {
                return parsed
            }
            if let nested = try? nestedContainer(keyedBy: AnyCodingKey.self, forKey: key),
               let value = nested.decodeLossyDouble(forKeys: ["value", "amount", "mm", "mmh", "mm_h", "in", "inhr", "in_h"]) {
                return value
            }
        }
        return nil
    }
}

private func parseLossyDouble(_ raw: String) -> Double? {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if let exact = Double(trimmed) {
        return exact
    }

    let filtered = trimmed.filter { "0123456789.-".contains($0) }
    return Double(filtered)
}

// MARK: - Daily Forecast

struct DailyForecast: Codable, Identifiable {
    let date: String
    let hi: Double?
    let lo: Double?
    let precipMm: Double?
    let precipProbPct: Int?
    let weatherCode: Int?
    let icon: String?
    let description: String?
    let sunrise: String?
    let sunset: String?
    
    var id: String { date }
    
    enum CodingKeys: String, CodingKey {
        case date, hi, lo
        case precipMm = "precip_mm"
        case precipProbPct = "precip_prob_pct"
        case weatherCode = "weather_code"
        case icon, description, sunrise, sunset
    }
}

// MARK: - Sun Position

struct SunPosition: Codable {
    let sunrise: String?
    let sunset: String?
    let daylightMinutes: Int?
    let nowAngle: Double?
    let isDaytime: Bool?
    
    enum CodingKeys: String, CodingKey {
        case sunrise, sunset
        case daylightMinutes = "daylight_minutes"
        case nowAngle = "now_angle"
        case isDaytime = "is_daytime"
    }
}

// MARK: - Moon Phase

struct MoonPhase: Codable {
    let phase: Double?
    let name: String?
    let illumination: Double?
    let emoji: String?
}

// MARK: - Metadata

struct WeatherMeta: Codable {
    let obsAgeS: Int?
    let forecastAgeS: Int?
    let generated: String?
    let timezone: String?
    
    enum CodingKeys: String, CodingKey {
        case obsAgeS = "obs_age_s"
        case forecastAgeS = "forecast_age_s"
        case generated, timezone
    }
}
