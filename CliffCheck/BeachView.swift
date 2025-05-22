import SwiftUI

struct BeachView: View {
    let name: String
    let tideHeight: Double
    let threshold: Double
    let timeUntilChange: String
    let isCheckmark: Bool
    let isRising: Bool

    var body: some View {
        VStack(spacing: 2) {
            Text(name)
                .font(.headline)
                .foregroundColor(.primary)

            HStack(spacing: 4) {
                Text(String(format: "%.1f ft", tideHeight))
                    .font(.title2)
                    .bold()
                    .foregroundColor(isCheckmark ? .blue : .red)
                Text(isRising ? "↑" : "↓")
                    .font(.title3)
                    .foregroundColor(.gray)
            }

            Image(systemName: isCheckmark ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 32))
                .foregroundColor(isCheckmark ? .green : .red)

            Text("Beachable when under \(String(format: "%.1f", threshold)) ft")
                .font(.footnote)
                .foregroundColor(.secondary)

            Text(timeUntilChange)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(isCheckmark ? Color.green.opacity(0.08) : Color.red.opacity(0.08))
        .cornerRadius(12)
        .frame(maxWidth: .infinity)
        .shadow(radius: 2)
        .padding(.horizontal, 2)
    }
}
