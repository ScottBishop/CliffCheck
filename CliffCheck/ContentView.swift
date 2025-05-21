import SwiftUI
import CoreLocation

struct ContentView: View {
    @Environment(\.colorScheme) var colorScheme
    @StateObject var tideService = TideService()
    @State private var sunsetTime: String = ""

    var backgroundGradient: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                gradient: Gradient(colors: [Color(.systemIndigo), Color(.black)]),
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            return LinearGradient(
                gradient: Gradient(colors: [Color(red: 0.87, green: 0.96, blue: 0.99), .white]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    var body: some View {
        ZStack {
            backgroundGradient.edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 20) {
                        HStack(spacing: 2) {
                            Text("Sunset Today: \(sunsetTime)")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.blue)
                                .padding(.top, 5)
                                .frame(maxWidth: .infinity, alignment: .center)
                            
                            Text("Current Tide: \(String(format: "%.1f", tideService.tides["New Break"] ?? 0)) ft")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.blue)
                                .padding(.top, 5)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .padding(.horizontal, 20)
                        
                        ForEach(tideService.beachThresholds.sorted(by: { $0.key < $1.key }), id: \.key) { beach, threshold in
                            let currentHeight = tideService.tides[beach] ?? 0
                            let timeChange = tideService.getTimeUntilThreshold(for: beach)
                            BeachView(name: beach, tideHeight: currentHeight, threshold: threshold, timeUntilChange: timeChange)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 40)
                }

                Spacer(minLength: 0)
                WaveView()
                    .frame(height: 60)
            }
        }
        .onAppear {
            tideService.fetchTideData()
            fetchSunset()
        }
    }

    private func fetchSunset() {
        let sunsetService = SunsetService()
        let location = CLLocationCoordinate2D(latitude: 32.716, longitude: -117.254)
        sunsetService.getSunsetTime(for: location) { time in
            self.sunsetTime = time
        }
    }
}
