import SwiftUI
import CoreLocation

struct ContentView: View {
    @StateObject var tideService = TideService()
    @State private var sunsetTime: String = ""
    @State private var currentTide: String = ""
    @State private var sunsetDate: Date?
    @State private var sunRotation = 0.0
    @Environment(\.scenePhase) var scenePhase

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                List {
                    VStack(spacing: 20) {
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

                        Text("Sunset Today: \(sunsetTime.isEmpty ? "Loading..." : sunsetTime)    Current Tide: \(currentTide)")
                            .font(.headline)
                            .foregroundColor(.blue)
                    }
                    .padding(.top, 4)
                    .listRowSeparator(.hidden)

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
                            .padding(.horizontal, 8)
                            .listRowSeparator(.hidden)
                    }
                }
                .refreshable {
                    await refreshData()
                }
                .listStyle(.plain)
                Spacer(minLength: 0)
                WaveView()
                    .frame(height: 70)
            }
        }
        .background(Color(.systemBackground).edgesIgnoringSafeArea(.all))
        .onAppear {
            Task {
                await refreshData()
            }
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                Task {
                    await refreshData()
                }
            }
        }
    }

    private func refreshData() async {
        await withCheckedContinuation { continuation in
            tideService.fetchTideData {
                if let anyForecast = tideService.tidesForecast.first?.value,
                   let closest = anyForecast.min(by: {
                       abs($0.dt - Date().timeIntervalSince1970) <
                       abs($1.dt - Date().timeIntervalSince1970)
                   }) {
                    let feet = closest.height * 3.28084
                    currentTide = String(format: "%.1f ft", feet)
                }
                fetchSunset()
                continuation.resume()
            }
        }
    }

    private func fetchSunset() {
        let sunsetService = SunsetService()
        let location = CLLocationCoordinate2D(latitude: 32.716, longitude: -117.254)
        sunsetService.getSunsetTime(for: location) { timeString in
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
                }
            }
        }
    }
}
