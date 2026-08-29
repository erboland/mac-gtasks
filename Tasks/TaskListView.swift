import SwiftUI

struct TaskListView: View {
    @EnvironmentObject private var session: SessionController
    @State private var draft = ""
    @FocusState private var addFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if let list = session.selectedList {
                header(list)
                Divider()
                if list.tasks.isEmpty {
                    emptyState(list)
                } else {
                    listBody(list)
                }
                addBar
            } else {
                ContentUnavailableView("No List", systemImage: "checklist", description: Text("Choose a list in the sidebar."))
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onChange(of: session.focusAddField) { _, focused in
            if focused {
                addFocused = true
                session.focusAddField = false
            }
        }
        .onChange(of: session.selectedListId) { _, _ in
            draft = ""
        }
    }

    private func header(_ list: TaskList) -> some View {
        let color = ListColor.color(for: list.id)
        return HStack(spacing: 12) {
            ListGlyph(color: color, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(list.title)
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(color)
                HStack(spacing: 8) {
                    Text("\(list.incompleteTasks.count) open")
                    if let synced = session.snapshot.lastSyncedAt {
                        Text("·")
                        Text(session.snapshot.isDemo ? "Demo" : "Updated \(synced.formatted(date: .omitted, time: .shortened))")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("Show Completed", isOn: $session.showCompleted)
                .toggleStyle(.checkbox)
                .font(.callout)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
    }

    private func listBody(_ list: TaskList) -> some View {
        List {
            ForEach(list.incompleteTasks) { task in
                TaskRowView(task: task, color: ListColor.color(for: list.id), subtasks: list.subtasks(of: task.id))
                    .listRowSeparator(.visible)
                    .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            Task { await session.delete(task) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }

            if session.showCompleted, !list.completedTasks.isEmpty {
                Section("Completed") {
                    ForEach(list.completedTasks) { task in
                        TaskRowView(task: task, color: ListColor.color(for: list.id), subtasks: [])
                            .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func emptyState(_ list: TaskList) -> some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(ListColor.color(for: list.id))
            Text("All Done")
                .font(.title2.weight(.semibold))
            Text("Add a task below, or check something off the widget.")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var addBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle.fill")
                .font(.title2)
                .foregroundStyle(session.selectedList.map { ListColor.color(for: $0.id) } ?? ListColor.remindersOrange)
            TextField("New Reminder", text: $draft)
                .textFieldStyle(.plain)
                .focused($addFocused)
                .onSubmit {
                    let title = draft
                    draft = ""
                    Task { await session.addTask(title: title) }
                    addFocused = true
                }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(.bar)
    }
}
