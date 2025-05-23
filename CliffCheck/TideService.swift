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

    private let pstTimeZone = TimeZone(identifier: "America/Los_Angeles")

    func fetchTideData(completion: (() -> Void)? = nil) {
        guard let apiKey = loadAPIKey() else {
            print("API key not found")
            completion?()
            return
        }

        let url = URL(string: "https://www.worldtides.info/api/v3?heights&date=today&days=1&localtime&datum=CD&step=60&lat=32.716&lon=-117.254&key=\(apiKey)")!

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

                let now = Date()

                let currentTide = decoded.heights.min(by: {
                    abs($0.dt - now.timeIntervalSince1970) < abs($1.dt - now.timeIntervalSince1970)
                }) ?? decoded.heights.first!

                DispatchQueue.main.async {
                    for (beach, threshold) in self.beachThresholds {
                        let previous = self.tides[beach] ?? 100.0
                        let tideInFeet = currentTide.height * 3.28084
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

                    let tideTime = Date(timeIntervalSince1970: currentTide.dt)
                    let tideFt = currentTide.height * 3.28084
                    print("🕓 Current Time: \(formatter.string(from: now)) PST")
                    print("🌊 Closest Tide: \(formatter.string(from: tideTime)) PST — \(String(format: "%.3f", currentTide.height)) m (\(String(format: "%.2f", tideFt)) ft)")

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

        for point in forecast {
            let pointInFeet = point.height * 3.28084
            let willBeCheckmark = pointInFeet <= threshold
            if willBeCheckmark != currentlyCheckmark {
                let now = Date()
                let timeUntil = point.dt - now.timeIntervalSince1970
                if timeUntil > 0 {
                    let hours = Int(timeUntil / 3600)
                    let minutes = Int((timeUntil.truncatingRemainder(dividingBy: 3600)) / 60)
                    let status = currentlyCheckmark ? "✓ Good for" : "✗ Returns in"
                    return "\(status) \(hours)h \(minutes)m"
                }
            }
        }

        
        let status = currentlyCheckmark ? "✓ Good all day" : "✗ Underwater all day"
        return status

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
    case stable
}

extension TideService {
    func getTideTrend(for beach: String) -> TideTrend {
        guard let forecast = self.tidesForecast[beach], forecast.count >= 2 else {
            return .stable
        }

        let sorted = forecast.sorted { $0.dt < $1.dt }
        let now = Date().timeIntervalSince1970
        guard let currentIndex = sorted.firstIndex(where: { $0.dt > now }) else {
            return .stable
        }

        let recent = sorted[max(0, currentIndex - 1)]
        let upcoming = sorted[min(sorted.count - 1, currentIndex)]

        let diff = upcoming.height - recent.height
        if diff > 0.01 {
            return .rising
        } else if diff < -0.01 {
            return .falling
        } else {
            return .stable
        }
    }
}
