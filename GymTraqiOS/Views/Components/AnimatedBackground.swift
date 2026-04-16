import SwiftUI

struct AnimatedBackground: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Orb 1 — blue
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(red: 0.1, green: 0.4, blue: 1.0).opacity(0.55), .clear],
                        center: .center, startRadius: 0, endRadius: 280
                    )
                )
                .frame(width: 480, height: 480)
                .offset(x: animate ? -80 : -40, y: animate ? -320 : -280)
                .blur(radius: 20)

            // Orb 2 — indigo
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(red: 0.45, green: 0.1, blue: 0.95).opacity(0.45), .clear],
                        center: .center, startRadius: 0, endRadius: 260
                    )
                )
                .frame(width: 440, height: 440)
                .offset(x: animate ? 140 : 100, y: animate ? -80 : -120)
                .blur(radius: 24)

            // Orb 3 — teal accent
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(red: 0.0, green: 0.75, blue: 0.8).opacity(0.3), .clear],
                        center: .center, startRadius: 0, endRadius: 200
                    )
                )
                .frame(width: 360, height: 360)
                .offset(x: animate ? -120 : -160, y: animate ? 260 : 220)
                .blur(radius: 30)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}
