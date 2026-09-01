import SwiftUI

@main
struct TasksApp: App {
    @StateObject private var session = SessionController()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if session.needsOnboarding {
                    OnboardingView()
                } else {
                    ContentView()
                }
            }
            .environmentObject(session)
            .onOpenURL { session.handle(url: $0) }
            .onReceive(DistributedNotificationCenter.default().publisher(for: AppGroup.composeNotification)) { note in
                session.beginCompose(listId: note.object as? String)
            }
            .frame(
                minWidth: session.needsOnboarding ? 640 : 720,
                minHeight: session.needsOnboarding ? 540 : 480
            )
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    session.consumePendingCompose()
                    Task { await session.refresh(userInitiated: false) }
                }
            }
            .onReceive(DistributedNotificationCenter.default().publisher(for: AppGroup.snapshotDidChange)) { _ in
                session.reloadFromDisk()
            }
        }
        .handlesExternalEvents(matching: ["*"])
        .windowStyle(.automatic)
        .defaultSize(width: 920, height: 620)
        .commands {
            CommandGroup(after: .newItem) {
                Button("New Task") {
                    session.beginCompose(listId: session.selectedListId)
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
