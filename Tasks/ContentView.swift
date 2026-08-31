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
        .tint(
            (session.selectedListId.map { ListColor.color(for: $0) })
                ?? ListColor.remindersOrange
        )
        .sheet(isPresented: $session.isComposing) {
            ComposeTaskSheet()
                .environmentObject(session)
        }
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
        .overlay {
            if session.isSyncing, session.snapshot.lists.isEmpty {
                ProgressView()
                    .controlSize(.regular)
            }
        }
        .safeAreaInset(edge: .top) {
            if session.showWidgetHint {
                widgetHint
            }
        }
    }

    private var widgetHint: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: "rectangle.stack.fill")
                .foregroundStyle(ListColor.remindersOrange)
            Text("Add Tasks to your desktop: Control-click the desktop → Edit Widgets → search Tasks.")
                .font(.callout)
            Spacer(minLength: 8)
            Button("Got it") {
                session.dismissWidgetHint()
            }
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }
}
