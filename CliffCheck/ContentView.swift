import SwiftUI
import CoreLocation

struct ContentView: View {
    @StateObject var tideService = TideService()
    @State private var sunsetTime: String = ""
    @State private var currentTide: String = ""
    @State private var sunsetDate: Date?
    @State private var isAnimatingSun = false
    @Environment(\.scenePhase) var scenePhase

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                List {
                    VStack(spacing: 16) {
                        Image(systemName: "sun.max.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.yellow)
                            .rotationEffect(.degrees(isAnimatingSun ? 360 : 0))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .onAppear {
                                withAnimation(Animation.linear(duration: 20).repeatForever(autoreverses: false)) {
                                    isAnimatingSun = true
                                }
                            }

                        if !tideService.tides.isEmpty {
                            let goodBeaches = tideService.tides.filter { beach, height in
                                let threshold = tideService.beachThresholds[beach] ?? 0
                                return height <= threshold
                            }.map { $0.key }

                            if goodBeaches.isEmpty {
                                Text("🌊 All beaches are currently under water")
                                    .font(.system(.title3, design: .rounded))
                                    .fontWeight(.medium)
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.red)
                                    .padding(.vertical, 8)
                                Text("Check back soon!")
                                    .font(.subheadline)
                                    .foregroundColor(.red.opacity(0.8))
                            } else {
                                Text("🏖️ Great time for:")
                                    .font(.system(.title3, design: .rounded))
                                    .fontWeight(.medium)
                                    .foregroundColor(.green.opacity(0.8))
                                    .padding(.bottom, 4)
                                Text(goodBeaches.joined(separator: ", "))
                                    .font(.headline)
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.green.opacity(0.8))
                                    .padding(.bottom, 8)
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
                    await refreshData(forceRefresh: true)
                }
                .listStyle(.plain)
                // Add some extra padding to the list content to prevent wave overlap
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 70)
                }
                
                WaveView()
                    .frame(height: 70)
                    .allowsHitTesting(false)
            }
        }
        .background(Color(.systemBackground).edgesIgnoringSafeArea(.all))
        .onAppear {
            Task {
                await refreshData(forceRefresh: true)
            }
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                Task {
                    await refreshData(forceRefresh: false)
                }
            }
        }
    }

    private func refreshData(forceRefresh: Bool = false) async {
        // First, fetch tide data
        await withCheckedContinuation { continuation in
            var hasResumed = false
            tideService.fetchTideData(forceRefresh: forceRefresh) {
                if !hasResumed {
                    hasResumed = true
                    if let anyForecast = tideService.tidesForecast.first?.value,
                       let closest = anyForecast.min(by: {
                           abs($0.dt - Date().timeIntervalSince1970) <
                           abs($1.dt - Date().timeIntervalSince1970)
                       }) {
                        let feet = closest.height * 3.28084
                        currentTide = String(format: "%.1f ft", feet)
                    }
                    continuation.resume()
                }
            }
        }
        
        // Then, fetch sunset data
        await withCheckedContinuation { continuation in
            var hasResumed = false
            fetchSunset() {
                if !hasResumed {
                    hasResumed = true
                    continuation.resume()
                }
            }
        }
    }

    private func fetchSunset(completion: @escaping () -> Void) {
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
            completion()
        }
    }
}
