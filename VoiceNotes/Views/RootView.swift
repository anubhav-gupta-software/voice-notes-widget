import SwiftUI

struct RootView: View {
    @Environment(NoteStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var store = store
        TabView(selection: $store.tab) {
            InboxView()
                .tabItem { Label("Inbox", systemImage: "tray.full") }
                .tag(AppTab.inbox)
                .badge(store.unheardCount)

            RecordView()
                .tabItem { Label("Record", systemImage: "mic.fill") }
                .tag(AppTab.record)

            FriendsView()
                .tabItem { Label("Friends", systemImage: "person.2") }
                .tag(AppTab.friends)
        }
        .tint(Theme.coral)
        .toolbarBackground(Theme.paper, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .fullScreenCover(isPresented: profileMissing) {
            OnboardingView()
                .interactiveDismissDisabled()
        }
        .sheet(isPresented: $store.showProfile) {
            ProfileSheet()
        }
        .sheet(item: $store.playerRoute) { route in
            PlayerSheet(route: route)
                .presentationDetents([.fraction(0.72), .large])
                .presentationDragIndicator(.hidden)
                .presentationBackground(Theme.paper)
        }
        .onOpenURL { url in
            store.handleOpenURL(url)
        }
        .task {
            store.startServices()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                store.refreshWidget()
                Task { await store.syncNow() }
            }
        }
    }

    private var profileMissing: Binding<Bool> {
        Binding(
            get: { store.profile == nil },
            set: { _ in }
        )
    }
}
