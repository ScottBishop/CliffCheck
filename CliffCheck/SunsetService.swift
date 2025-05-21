import Foundation
import CoreLocation

class SunsetService {
    func getSunsetTime(for location: CLLocationCoordinate2D, completion: @escaping (String) -> Void) {
        let url = URL(string: "https://api.sunrisesunset.io/json?lat=\(location.latitude)&lng=\(location.longitude)&timezone=auto")!
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data else { return }
            if let decoded = try? JSONDecoder().decode(SunsetResponse.self, from: data) {
                let sunsetString = decoded.results.sunset
                let formatted = self.reformatSunsetTime(sunsetString)
                DispatchQueue.main.async {
                    completion(formatted)
                }
            }
        }.resume()
    }
    
    private func reformatSunsetTime(_ timeString: String) -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "h:mm:ss a"
        inputFormatter.amSymbol = "AM"
        inputFormatter.pmSymbol = "PM"
        
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "h:mm a"
        outputFormatter.amSymbol = "AM"
        outputFormatter.pmSymbol = "PM"
        
        if let date = inputFormatter.date(from: timeString) {
            return outputFormatter.string(from: date)
        } else {
            return timeString // fallback if parsing fails
        }
    }
}
struct SunsetResponse: Codable {
    let results: SunsetResults
}

struct SunsetResults: Codable {
    let sunset: String
}
