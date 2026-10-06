import SwiftUI

struct HistoryView: View {
    @Environment(Store.self) private var store

    private var grouped: [(day: Date, items: [Session])] {
        let cal = Calendar.current
        let dict = Dictionary(grouping: store.sessions) { cal.startOfDay(for: $0.start) }
        return dict.keys.sorted(by: >).map { ($0, dict[$0]!.sorted { $0.start > $1.start }) }
    }

    var body: some View {
        NavigationStack {
            Screen {
                ScreenHeader(kicker: "\(store.totalShots.formatted()) shots", title: "History")
                ForEach(grouped, id: \.day) { group in
                    SectionLabel(group.day.formatted(.dateTime.weekday(.wide).month().day()).uppercased())
                    ForEach(group.items) { s in
                        NavigationLink(value: s) { SessionRow(session: s) }.buttonStyle(.plain)
                            .contextMenu { Button("Delete session", role: .destructive) { store.delete(s) } }
                    }
                }
                if store.sessions.isEmpty {
                    Text("Your sessions will show up here.").font(.system(size: 13)).foregroundStyle(Theme.muted).frame(maxWidth: .infinity).card(padding: 24)
                }
            }
            .navigationDestination(for: Session.self) { SessionDetailView(session: $0) }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}
