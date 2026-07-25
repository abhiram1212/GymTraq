import SwiftUI

/// Launch screen shown while the app prefetches profile + catalog data.
struct SplashView: View {
    @State private var appear = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            RadialGradient(colors: [Color.appAccent.opacity(0.18), .clear],
                           center: .center, startRadius: 0, endRadius: 420)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ZStack {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(
                            LinearGradient(colors: [Color.appAccent, Color.appAccentDeep],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 116, height: 116)
                        .shadow(color: Color.appAccent.opacity(0.4), radius: 24, y: 8)
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 52, weight: .bold))
                        .foregroundStyle(.black)
                }
                .scaleEffect(appear ? 1 : 0.6)
                .opacity(appear ? 1 : 0)

                Text("GymTraq")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .opacity(appear ? 1 : 0)

                ProgressView()
                    .tint(.white.opacity(0.5))
                    .padding(.top, 8)
                    .opacity(appear ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) { appear = true }
        }
    }
}
