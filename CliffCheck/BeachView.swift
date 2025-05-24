import SwiftUI

struct BeachView: View {
    let name: String
    let tideHeight: Double
    let threshold: Double
    let timeUntilChange: String
    let isCheckmark: Bool
    let isRising: Bool

    var body: some View {
        VStack(spacing: 4) {
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
                .foregroundColor(Color.primary.opacity(0.7))

            Text(timeUntilChange)
                .font(.caption2)
                .foregroundColor(Color.primary.opacity(0.7))
        }
        .padding()
        .background(isCheckmark ? Color.green.opacity(0.08) : Color.red.opacity(0.08))
        .cornerRadius(14)
        .frame(maxWidth: .infinity)
        .shadow(radius: 2)
        .padding(.horizontal, 8)
    }
}

#Preview {
    BeachView(
        name: "New Break",
        tideHeight: 3.5,
        threshold: 1.5,
        timeUntilChange: "× Underwater all day",
        isCheckmark: false,
        isRising: false
    )
    .padding()
    .background(Color(.systemBackground))
    .previewLayout(.sizeThatFits)
    .preferredColorScheme(.dark)
}
