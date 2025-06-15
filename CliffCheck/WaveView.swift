import SwiftUI

struct WaveAnimationModifier: ViewModifier {
    let amplitude: CGFloat
    let frequency: Double
    let isAnimating: Bool
    
    @State private var offsetY: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .offset(y: offsetY)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 1/frequency)
                    .repeatForever(autoreverses: true)
                ) {
                    offsetY = amplitude
                }
            }
    }
}

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
        let width = rect.width

        // Start drawing from outside the left edge
        path.move(to: CGPoint(x: -width, y: rect.height))
        
        // Draw waves across an extended width (3x normal width)
        for x in stride(from: -width, through: width * 2, by: 1) {
            let relativeX = x / width
            let sine = sin((relativeX + phase) * .pi * 2 * frequency)
            let y = midHeight + CGFloat(sine) * CGFloat(strength)
            path.addLine(to: CGPoint(x: x, y: y))
        }

        // Complete the path by extending to the right edge
        path.addLine(to: CGPoint(x: width * 2, y: rect.height))
        path.addLine(to: CGPoint(x: -width, y: rect.height))
        path.closeSubpath()

        return path
    }
}

struct WaveView: View {
    @State private var phase: Double = 0

    var body: some View {
        ZStack {
            // Background wave
            Wave(strength: 10, frequency: 1.5, phase: phase)
                .fill(Color.blue.opacity(0.15))
                .frame(height: 100)
                .offset(y: 30)
                .clipShape(Rectangle())
                .modifier(WaveAnimationModifier(amplitude: 3, frequency: 0.5, isAnimating: true))

            // Middle wave
            Wave(strength: 15, frequency: 1.2, phase: phase * 0.9)
                .fill(Color.blue.opacity(0.2))
                .frame(height: 120)
                .offset(y: 15)
                .clipShape(Rectangle())
                .modifier(WaveAnimationModifier(amplitude: 4, frequency: 0.4, isAnimating: true))

            // Foreground wave
            Wave(strength: 18, frequency: 1.0, phase: phase * 0.8)
                .fill(Color.blue.opacity(0.25))
                .frame(height: 130)
                .clipShape(Rectangle())
                .modifier(WaveAnimationModifier(amplitude: 5, frequency: 0.3, isAnimating: true))
        }
        .onAppear {
            withAnimation(.linear(duration: 16).repeatForever(autoreverses: false)) {
                phase = 4
            }
        }
    }
    }

