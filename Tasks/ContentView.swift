import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var session: SessionController

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 300)
        } detail: {
            TaskListView()
        }
        .tint(session.selectedList.map { ListColor.color(for: $0.id) } ?? ListColor.remindersOrange)
        .alert("Couldn’t sync", isPresented: Binding(
            get: { session.errorMessage != nil },
            set: { if !$0 { session.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { session.errorMessage = nil }
        } message: {
            Text(session.errorMessage ?? "")
        }
        .task {
            if session.isSignedIn {
                await session.refresh()
            }
        }
    }
}
