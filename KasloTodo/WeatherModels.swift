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
