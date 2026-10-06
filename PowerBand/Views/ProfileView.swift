import SwiftUI

struct ProfileView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @AppStorage("dailyGoal") private var goal = 200
    @AppStorage("hapticsOn") private var hapticsOn = true
    @AppStorage("voiceOn") private var voiceOn = false

    var body: some View {
        NavigationStack {
            Screen {
                HStack(spacing: 10) {
                    StatTile(label: "Streak", value: "\(store.streak)", unit: "days", sub: "Best \(store.bestStreak)", subColor: Theme.volt)
                    StatTile(label: "Total shots", value: store.totalShots.formatted(), sub: "\(store.sessions.count) sessions")
                }
                .fixedSize(horizontal: false, vertical: true)

                SectionLabel("DAILY GOAL")
                VStack(spacing: 10) {
                    Stepper(value: $goal, in: 50...1000, step: 25) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) { Text("\(goal)").font(.num(30)).foregroundStyle(.white); Text("shots a day").font(.system(size: 12)).foregroundStyle(Theme.muted) }
                    }
                    Toggle("Haptic tap on every shot", isOn: $hapticsOn)
                    Toggle("Speak swing speed aloud", isOn: $voiceOn)
                }
                .font(.system(size: 14, weight: .medium)).tint(Theme.green).card()

                let unlocked = Achievements.all.filter { $0.unlocked(store) }
                SectionLabel("ACHIEVEMENTS  \(unlocked.count)/\(Achievements.all.count)")
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(Achievements.all) { a in
                        let on = a.unlocked(store)
                        VStack(alignment: .leading, spacing: 8) {
                            Image(systemName: a.symbol).font(.system(size: 20, weight: .semibold)).foregroundStyle(on ? Theme.volt : Color(hex: 0x4A545B))
                                .frame(width: 42, height: 42).background((on ? Theme.volt : Color.white).opacity(on ? 0.14 : 0.05), in: Circle())
                            Text(a.title).font(.system(size: 14, weight: .bold)).foregroundStyle(on ? .white : Theme.muted)
                            Text(a.detail).font(.system(size: 11)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading).card(padding: 12).opacity(on ? 1 : 0.7)
                    }
                }
            }
            .navigationTitle("You").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .toolbarBackground(Theme.bg, for: .navigationBar)
        }
    }
}
