import SwiftUI
import CoreLocation

struct ContentView: View {
    @StateObject var tideService = TideService()
    @State private var sunsetTime: String = "Loading..."
    @State private var currentTide: String = ""
    @State private var sunsetDate: Date?
    @State private var backgroundTint: Color = .white
    @State private var sunRotation = 0.0
    @State private var isRefreshing = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    if isRefreshing {
                        ProgressView("Refreshing...")
                            .progressViewStyle(CircularProgressViewStyle())
                            .padding(.top, 10)
                    }

                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.yellow)
                        .rotationEffect(.degrees(sunRotation))
                        .onAppear {
                            withAnimation(Animation.linear(duration: 20).repeatForever(autoreverses: false)) {
                                sunRotation = 360
                            }
                        }

                    if !tideService.tides.isEmpty {
                        let goodBeaches = tideService.tides.filter { beach, height in
                            let threshold = tideService.beachThresholds[beach] ?? 0
                            return height <= threshold
                        }.map { $0.key }

                        if goodBeaches.isEmpty {
                            Text("🌊 All beaches are currently under water — check back soon!")
                                .font(.subheadline)
                                .padding(.bottom, 5)
                                .foregroundColor(.red)
                        } else {
                            Text("🏖️ Great time for: \(goodBeaches.joined(separator: ", "))!")
                                .font(.subheadline)
                                .padding(.bottom, 5)
                                .foregroundColor(.green)
                        }
                    }

                    Text("Sunset Today: \(sunsetTime)    Current Tide: \(currentTide)")
                        .font(.headline)
                        .foregroundColor(.blue)

                    ForEach(tideService.beachThresholds.sorted(by: { $0.key < $1.key }), id: \.key) { beach, threshold in
                        let height = tideService.tides[beach] ?? 0
                        let trend = tideService.getTideTrend(for: beach)
                        let timeChange = tideService.getTimeUntilThreshold(for: beach)

                        BeachView(name: beach,
                                  tideHeight: height,
                                  threshold: threshold,
                                  timeUntilChange: timeChange,
                                  isCheckmark: height <= threshold,
                                  isRising: trend == .rising)
                            .padding(.horizontal, 2)
                    }
                }
                .padding(.top, 20)
            }
            .refreshable {
                isRefreshing = true
                tideService.fetchTideData {
                    if let anyForecast = tideService.tidesForecast.first?.value,
                       let closest = anyForecast.min(by: {
                           abs($0.dt - Date().timeIntervalSince1970) <
                           abs($1.dt - Date().timeIntervalSince1970)
                       }) {
                        let feet = closest.height * 3.28084
                        currentTide = String(format: "%.1f ft", feet)
                    }
                    isRefreshing = false
                }
                fetchSunset()
            }

            Spacer(minLength: 0)
            WaveView()
                .frame(height: 70)
        }
        .background(backgroundTint.edgesIgnoringSafeArea(.all))
        .onAppear {
            tideService.fetchTideData {
                if let anyForecast = tideService.tidesForecast.first?.value,
                   let closest = anyForecast.min(by: {
                       abs($0.dt - Date().timeIntervalSince1970) <
                       abs($1.dt - Date().timeIntervalSince1970)
                   }) {
                    let feet = closest.height * 3.28084
                    currentTide = String(format: "%.1f ft", feet)
                }
            }
            fetchSunset()
        }
    }

    private func fetchSunset() {
        let sunsetService = SunsetService()
        let location = CLLocationCoordinate2D(latitude: 32.716, longitude: -117.254)

        sunsetService.getSunsetTime(for: location) { timeString in
            DispatchQueue.main.async {
                guard !timeString.isEmpty else {
                    print("⚠️ Failed to load sunset time.")
                    self.sunsetTime = "Unavailable"
                    return
                }

                self.sunsetTime = timeString

                let formatter = DateFormatter()
                formatter.dateFormat = "h:mm a"
                formatter.timeZone = TimeZone(identifier: "America/Los_Angeles")
                if let date = formatter.date(from: timeString) {
                    let calendar = Calendar.current
                    let now = Date()
                    let components = calendar.dateComponents([.year, .month, .day], from: now)
                    if let today = calendar.date(from: components) {
                        self.sunsetDate = Calendar.current.date(bySettingHour: Calendar.current.component(.hour, from: date),
                                                                 minute: Calendar.current.component(.minute, from: date),
                                                                 second: 0,
                                                                 of: today)
                        updateBackgroundTint()
                    }
                } else {
                    print("⚠️ Could not parse sunset time: \(timeString)")
                }
            }
        }
    }

    private func computeMinutesUntilSunset() -> Int {
        guard let sunset = sunsetDate else { return 999 }
        let interval = sunset.timeIntervalSinceNow
        return max(0, Int(interval / 60))
    }

    private func updateBackgroundTint() {
        let minutesUntilSunset = computeMinutesUntilSunset()
        if minutesUntilSunset < 30 {
            backgroundTint = Color.orange.opacity(0.1)
        } else if minutesUntilSunset < 60 {
            backgroundTint = Color.yellow.opacity(0.1)
        } else {
            backgroundTint = Color.white
        }
    }
}
