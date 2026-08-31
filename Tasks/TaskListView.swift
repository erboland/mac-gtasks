import SwiftUI

struct TaskListView: View {
    @EnvironmentObject private var session: SessionController
    @State private var draft = ""
    @State private var readyForListId: String?
    @FocusState private var addFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if let list = session.selectedList {
                header(list)
                Divider()
                if showTaskRows {
                    if list.incompleteTasks.isEmpty && (!session.showCompleted || list.completedTasks.isEmpty) {
                        emptyState(list)
                    } else {
                        listBody(list)
                    }
                } else {
                    ProgressView()
                        .controlSize(.regular)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                addBar
            } else {
                ContentUnavailableView("No List", systemImage: "checklist", description: Text("Choose a list in the sidebar."))
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .task(id: "\(session.selectedListId ?? "")-\(session.showCompleted)") {
            let id = session.selectedListId
            if shouldDeferHeavyList {
                await Task.yield()
            }
            guard !Task.isCancelled, session.selectedListId == id else { return }
            readyForListId = id
        }
        .animation(nil, value: session.selectedListId)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    session.beginCompose(listId: session.selectedListId)
                } label: {
                    Image(systemName: "plus")
                }
                .help("New Task")
                .disabled(session.selectedList == nil)
            }
        }
        .onChange(of: session.focusAddField) { _, focused in
            if focused {
                addFocused = true
                session.focusAddField = false
            }
        }
        .onChange(of: session.selectedListId) { _, _ in
            draft = ""
            readyForListId = nil
        }
    }

    private var shouldDeferHeavyList: Bool {
        guard let list = session.selectedList, session.showCompleted else { return false }
        return list.tasks.count > 40
    }

    private var showTaskRows: Bool {
        guard let id = session.selectedListId else { return false }
        if !shouldDeferHeavyList { return true }
        return readyForListId == id
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
                    if !list.completedTasks.isEmpty {
                        Text("·")
                        Text("\(list.completedTasks.count) completed")
                    }
                    if session.isSyncing {
                        Text("·")
                        ProgressView()
                            .controlSize(.small)
                    } else if let synced = session.snapshot.lastSyncedAt {
                        Text("·")
                        Text(session.snapshot.isDemo ? "Demo" : "Updated \(synced.formatted(date: .omitted, time: .shortened))")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                session.beginCompose(listId: list.id)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(color)
            }
            .buttonStyle(.plain)
            .help("New Task")
            Toggle("Show Completed", isOn: $session.showCompleted)
                .toggleStyle(.checkbox)
                .font(.callout)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
    }

    private func listBody(_ list: TaskList) -> some View {
        let open = session.openTasks(in: list)
        let completed = session.showCompleted ? session.completedTasks(in: list) : []
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(open) { task in
                    TaskRowView(task: task, color: ListColor.color(for: list.id), subtasks: list.subtasks(of: task.id))
                    Divider()
                }

                if session.showCompleted {
                    HStack {
                        Text("Completed (\(list.completedTasks.count))")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.top, 18)
                    .padding(.bottom, 8)

                    if completed.isEmpty {
                        Text("No completed tasks")
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(completed) { task in
                            TaskRowView(task: task, color: ListColor.color(for: list.id), subtasks: [])
                            Divider()
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .id(list.id)
        .refreshable {
            await session.refresh()
        }
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

struct ComposeTaskSheet: View {
    @EnvironmentObject private var session: SessionController
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var notes = ""
    @State private var hasDue = false
    @State private var due = Date()
    @FocusState private var titleFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Task")
                .font(.title2.weight(.semibold))
            if let list = session.selectedList {
                Text(list.title)
                    .font(.subheadline)
                    .foregroundStyle(ListColor.color(for: list.id))
            }
            TextField("Title", text: $title)
                .textFieldStyle(.roundedBorder)
                .focused($titleFocused)
                .onSubmit { submit() }
            TextField("Notes", text: $notes, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)
            Toggle("Due date", isOn: $hasDue)
            if hasDue {
                DatePicker("Due", selection: $due, displayedComponents: .date)
                    .datePickerStyle(.graphical)
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add") { submit() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(minWidth: 420)
        .onAppear { titleFocused = true }
    }

    private func submit() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let note = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            await session.addTask(
                title: trimmed,
                notes: note.isEmpty ? nil : note,
                due: hasDue ? due : nil
            )
        }
        dismiss()
    }
}
