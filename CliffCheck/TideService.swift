import Foundation
import UserNotifications
import SwiftUI
import CoreLocation

class TideService: ObservableObject {
    @Published var tides: [String: Double] = [:]
    @Published var tidesForecast: [String: [TideData]] = [:]

    let beachThresholds: [String: Double] = [
        "New Break": 1.5,
        "Bermuda Beach": 4.0,
        "Kellogg Beach": 5.5
    ]

    private let pstTimeZone = TimeZone(identifier: "America/Los_Angeles") ?? TimeZone.current

    func fetchTideData(completion: (() -> Void)? = nil) {
        guard let apiKey = loadAPIKey() else {
            print("API key not found")
            completion?()
            return
        }

        let url = URL(string: "https://www.worldtides.info/api/v3?heights&date=today&days=1&localtime&datum=CD&step=600&lat=32.716&lon=-117.254&key=\(apiKey)")!

        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data else {
                print("No data returned")
                completion?()
                return
            }
            do {
                let decoded = try JSONDecoder().decode(TideResponse.self, from: data)

                if decoded.heights.isEmpty {
                    print("No tide data available.")
                    completion?()
                    return
                }

                let now = Date().timeIntervalSince1970

                let sortedHeights = decoded.heights.sorted(by: { $0.dt < $1.dt })

                guard let lower = sortedHeights.last(where: { $0.dt <= now }),
                      let upper = sortedHeights.first(where: { $0.dt > now }) else {
                    print("Unable to interpolate tide height.")
                    completion?()
                    return
                }

                let totalDuration = upper.dt - lower.dt
                let elapsed = now - lower.dt
                let ratio = elapsed / totalDuration
                let interpolatedHeight = lower.height + ratio * (upper.height - lower.height)
                let tideInFeet = interpolatedHeight * 3.28084
                print("🔍 Raw interpolated height: \(String(format: "%.4f", interpolatedHeight)) meters")
                print("📏 Converted height: \(String(format: "%.2f", tideInFeet)) ft")

                DispatchQueue.main.async {
                    for (beach, threshold) in self.beachThresholds {
                        let previous = self.tides[beach] ?? 100.0
                        if previous > threshold && tideInFeet <= threshold {
                            self.sendNotification(for: beach)
                        }
                        self.tides[beach] = tideInFeet
                        self.tidesForecast[beach] = decoded.heights
                    }

                    let formatter = DateFormatter()
                    formatter.timeZone = self.pstTimeZone
                    formatter.dateFormat = "yyyy-MM-dd HH:mm"

                    print("📡 WorldTides API Response:")
                    for point in decoded.heights.prefix(20) {
                        let time = Date(timeIntervalSince1970: point.dt)
                        let ft = point.height * 3.28084
                        print("- \(formatter.string(from: time)) PST — \(String(format: "%.3f", point.height)) m (\(String(format: "%.2f", ft)) ft)")
                    }

                    let tideTime = Date()
                    print("🕓 Current Time: \(formatter.string(from: Date(timeIntervalSince1970: now))) PST")
                    print("🌊 Interpolated Tide: \(String(format: "%.3f", interpolatedHeight)) m (\(String(format: "%.2f", tideInFeet)) ft)")

                    completion?()
                }
            } catch {
                print("Error decoding tide data: \(error)")
                completion?()
            }
        }.resume()
    }

    func getTimeUntilThreshold(for beach: String) -> String {
        guard let forecast = self.tidesForecast[beach] else { return "No data" }
        guard let threshold = beachThresholds[beach] else { return "No threshold" }
        guard let currentHeight = tides[beach] else { return "No current tide" }

        let currentlyCheckmark = currentHeight <= threshold
        let now = Date().timeIntervalSince1970

        // Track state and search for the next crossing point
        var previousState: Bool? = nil

        for point in forecast {
            let pointInFeet = point.height * 3.28084
            let pointState = pointInFeet <= threshold

            // Skip points in the past
            if point.dt <= now {
                previousState = pointState
                continue
            }

            // Detect transition only if it flips from the current state
            if let previous = previousState, previous != pointState && pointState != currentlyCheckmark {
                let timeUntil = point.dt - now
                let hours = Int(timeUntil / 3600)
                let minutes = Int((timeUntil.truncatingRemainder(dividingBy: 3600)) / 60)
                let status = currentlyCheckmark ? "✓ Good for" : "✗ Returns in"
                return "\(status) \(hours)h \(minutes)m"
            }

            previousState = pointState
        }

        // No change detected in the forecast period
        return currentlyCheckmark ? "✓ Good all day" : "✗ Underwater all day"
    }

    private func sendNotification(for beach: String) {
        let content = UNMutableNotificationContent()
        content.title = "Tide Alert"
        content.body = "\(beach) is now a check mark!"
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    private func loadAPIKey() -> String? {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dict = plist as? [String: Any] else {
            return nil
        }
        return dict["WorldTidesAPIKey"] as? String
    }
}

struct TideResponse: Codable {
    let heights: [TideData]
}

struct TideData: Codable {
    let dt: TimeInterval
    let height: Double
}

enum TideTrend {
    case rising
    case falling
    case steady
}

extension TideService {
    func getTideTrend(for beach: String) -> TideTrend {
        guard let forecast = tidesForecast[beach] else { return .steady }

        let now = Date().timeIntervalSince1970
        let sorted = forecast.sorted(by: { $0.dt < $1.dt })

        guard let past = sorted.last(where: { $0.dt < now }),
              let future = sorted.first(where: { $0.dt > now }) else {
            return .steady
        }

        if future.height > past.height {
            return .rising
        } else if future.height < past.height {
            return .falling
        } else {
            return .steady
        }
    }
}
