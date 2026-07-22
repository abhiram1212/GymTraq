import SwiftUI

// Calm, static backdrop in the style of Apple's own dark-mode apps: true black
// with a barely-there accent wash for depth. Replaces the perpetually animating
// orbs — Apple apps keep backgrounds still and put motion into interactions,
// and a static backdrop costs the GPU nothing.
struct AnimatedBackground: View {
    var body: some View {
        ZStack {
            Color.black

            RadialGradient(
                colors: [Color.appAccent.opacity(0.07), .clear],
                center: .topLeading, startRadius: 0, endRadius: 520
            )

            RadialGradient(
                colors: [Color.appAccentDeep.opacity(0.05), .clear],
                center: .bottomTrailing, startRadius: 0, endRadius: 460
            )
        }
        .ignoresSafeArea()
    }
}
