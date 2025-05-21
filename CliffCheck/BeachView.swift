import SwiftUI

struct BeachView: View {
    let name: String
    let tideHeight: Double
    let threshold: Double
    let timeUntilChange: String

    var body: some View {
        VStack(spacing: 10) {
            Text(name)
                .font(.system(.title3, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(.primary)

            Text(String(format: "%.1f ft", tideHeight))
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(.blue)

            Image(systemName: tideHeight <= threshold ? "checkmark.circle.fill" : "xmark.circle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 48, height: 48)
                .foregroundColor(tideHeight <= threshold ? .green : .red)

            Text("Checkmark when under: \(String(format: "%.1f", threshold)) ft")
                .font(.footnote)
                .foregroundColor(.secondary)
            
            if (timeUntilChange != "Stays same") {
                let changesToX = tideHeight <= threshold ? "Changes to X at " : "Changes to Checkmark at "
                Text("\(changesToX)\(timeUntilChange)")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [.white, Color.blue.opacity(0.05)]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}
