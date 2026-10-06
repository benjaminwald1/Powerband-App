import SwiftUI

struct OnboardingView: View {
    var done: () -> Void
    @State private var page = 0

    private let pages: [(icon: String, title: String, body: String)] = [
        ("dot.scope", "One sensor.\nMore ways to play.", "A coin-sized sensor that tracks every swing in tennis, pickleball, padel, golf and boxing. No screen. Just play."),
        ("chart.line.uptrend.xyaxis", "Every shot,\nmeasured.", "Swing speed, ball speed, spin, racquet path and contact point show up here the moment you finish the point."),
        ("lock.shield.fill", "Your data is\nyours.", "Sessions are stored on your phone. Nothing is sold or uploaded. Export or delete everything whenever you like."),
    ]

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 24) {
                HStack(spacing: 6) {
                    Text("P").font(.system(size: 22, weight: .heavy, design: .default).italic())
                    Text("PowerBand").font(.system(size: 20, weight: .bold))
                }
                .foregroundStyle(.white).padding(.top, 20)

                TabView(selection: $page) {
                    ForEach(pages.indices, id: \.self) { i in
                        VStack(spacing: 22) {
                            ZStack {
                                Circle().stroke(Theme.track, lineWidth: 12).frame(width: 190, height: 190)
                                Circle().trim(from: 0, to: [0.87, 0.68, 0.92][i]).stroke(Theme.green, style: StrokeStyle(lineWidth: 12, lineCap: .round)).rotationEffect(.degrees(-90)).frame(width: 190, height: 190).shadow(color: Theme.green.opacity(0.6), radius: 10)
                                Image(systemName: pages[i].icon).font(.system(size: 62, weight: .medium)).foregroundStyle(.white)
                            }
                            .padding(.top, 20)
                            Text(pages[i].title).font(.num(40)).multilineTextAlignment(.center).foregroundStyle(.white)
                            Text(pages[i].body).font(.system(size: 15)).multilineTextAlignment(.center).foregroundStyle(Theme.muted).padding(.horizontal, 30)
                        }.tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                Button { if page < pages.count - 1 { withAnimation { page += 1 } } else { done() } } label: {
                    Text(page < pages.count - 1 ? "Continue" : "Get started").font(.system(size: 17, weight: .bold)).frame(maxWidth: .infinity).padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent).tint(Theme.green).foregroundStyle(.black).padding(.horizontal, 24)

                Text("By continuing you agree to the [Terms of Service](https://powerband.fit/terms/) and [Privacy Policy](https://powerband.fit/privacy/).")
                    .font(.system(size: 11)).foregroundStyle(Theme.muted).multilineTextAlignment(.center).padding(.horizontal, 32).padding(.bottom, 14)
            }
        }
    }
}
