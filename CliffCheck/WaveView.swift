import SwiftUI

struct Wave: Shape {
    var strength: Double
    var frequency: Double
    var phase: Double

    var animatableData: Double {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midHeight = rect.height / 2

        path.move(to: CGPoint(x: 0, y: midHeight))

        for x in stride(from: 0, through: rect.width, by: 1) {
            let relativeX = x / rect.width
            let sine = sin((relativeX + phase) * .pi * 2 * frequency)
            let y = midHeight + CGFloat(sine) * CGFloat(strength)
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()

        return path
    }
}

struct WaveView: View {
    @State private var phase1: Double = 0
    @State private var phase2: Double = 0

    var body: some View {
        ZStack {
            Wave(strength: 10, frequency: 1.5, phase: phase1)
                .fill(Color.blue.opacity(0.2))
                .frame(height: 100)
                .offset(y: 30)
                .animation(.linear(duration: 6).repeatForever(autoreverses: false), value: phase1)

            Wave(strength: 15, frequency: 1.2, phase: phase2)
                .fill(Color.blue.opacity(0.3))
                .frame(height: 120)
                .animation(.linear(duration: 8).repeatForever(autoreverses: false), value: phase2)
        }
        .onAppear {
            withAnimation {
                phase1 = 1
                phase2 = 1
            }
        }
    }
}
