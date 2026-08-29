import SwiftUI
import WidgetKit

@main
struct TasksApp: App {
    @StateObject private var session = SessionController()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(session)
                .onOpenURL { session.handle(url: $0) }
                .frame(minWidth: 720, minHeight: 480)
        }
        .windowStyle(.automatic)
        .defaultSize(width: 920, height: 620)
        .commands {
            CommandGroup(after: .newItem) {
                Button("New Task") {
                    session.focusAddField = true
                }
                .keyboardShortcut("n", modifiers: [.command])

                Button("Refresh") {
                    Task { await session.refresh() }
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
        }
    }
}
