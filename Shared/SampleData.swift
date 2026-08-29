import Foundation

enum SampleData {
    static func snapshot() -> TasksSnapshot {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let nextWeek = calendar.date(byAdding: .day, value: 5, to: today)!

        let myTasks = TaskList(
            id: "demo-my-tasks",
            title: "Reminders",
            updated: Date(),
            tasks: [
                TaskItem(id: "t1", listId: "demo-my-tasks", title: "Review design mockups", notes: "Check spacing against the latest spec", status: "needsAction", due: today, completed: nil, updated: Date(), parent: nil, position: "00001", webViewLink: nil),
                TaskItem(id: "t2", listId: "demo-my-tasks", title: "Send weekly update", notes: nil, status: "needsAction", due: today, completed: nil, updated: Date(), parent: nil, position: "00002", webViewLink: nil),
                TaskItem(id: "t3", listId: "demo-my-tasks", title: "Pick up dry cleaning", notes: nil, status: "needsAction", due: tomorrow, completed: nil, updated: Date(), parent: nil, position: "00003", webViewLink: nil),
                TaskItem(id: "t4", listId: "demo-my-tasks", title: "Renew parking permit", notes: "Office closes at 4pm", status: "needsAction", due: yesterday, completed: nil, updated: Date(), parent: nil, position: "00004", webViewLink: nil),
                TaskItem(id: "t5", listId: "demo-my-tasks", title: "Book dentist", notes: nil, status: "needsAction", due: nextWeek, completed: nil, updated: Date(), parent: nil, position: "00005", webViewLink: nil),
                TaskItem(id: "t6", listId: "demo-my-tasks", title: "Water the plants", notes: nil, status: "completed", due: yesterday, completed: Date(), updated: Date(), parent: nil, position: "00006", webViewLink: nil)
            ]
        )

        let groceries = TaskList(
            id: "demo-groceries",
            title: "Groceries",
            updated: Date(),
            tasks: [
                TaskItem(id: "g1", listId: "demo-groceries", title: "Oat milk", notes: nil, status: "needsAction", due: nil, completed: nil, updated: Date(), parent: nil, position: "00001", webViewLink: nil),
                TaskItem(id: "g2", listId: "demo-groceries", title: "Sourdough", notes: nil, status: "needsAction", due: nil, completed: nil, updated: Date(), parent: nil, position: "00002", webViewLink: nil),
                TaskItem(id: "g3", listId: "demo-groceries", title: "Blueberries", notes: nil, status: "needsAction", due: today, completed: nil, updated: Date(), parent: nil, position: "00003", webViewLink: nil)
            ]
        )

        return TasksSnapshot(
            accountEmail: nil,
            isDemo: true,
            lists: [myTasks, groceries],
            selectedListId: myTasks.id,
            lastSyncedAt: Date()
        )
    }
}
