import SwiftUI

struct TaskRowView: View {
    @EnvironmentObject private var session: SessionController
    var task: TaskItem
    var color: Color
    var subtasks: [TaskItem]
    @State private var editingTitle: String = ""
    @FocusState private var isEditing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Button {
                    Task { await session.toggle(task) }
                } label: {
                    RemindersCheckbox(isCompleted: task.isCompleted, color: color)
                }
                .buttonStyle(.plain)
                .padding(.top, 1)

                VStack(alignment: .leading, spacing: 2) {
                    TextField("Task", text: $editingTitle)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16))
                        .strikethrough(task.isCompleted, color: .secondary)
                        .foregroundStyle(task.isCompleted ? .secondary : .primary)
                        .focused($isEditing)
                        .onSubmit {
                            Task { await session.rename(task, title: editingTitle) }
                        }
                        .onChange(of: isEditing) { _, focused in
                            if !focused, editingTitle != task.title {
                                Task { await session.rename(task, title: editingTitle) }
                            }
                        }

                    metadata
                }
                Spacer(minLength: 0)
            }

            ForEach(subtasks) { child in
                HStack(spacing: 12) {
                    Spacer().frame(width: 22)
                    Button {
                        Task { await session.toggle(child) }
                    } label: {
                        RemindersCheckbox(isCompleted: child.isCompleted, color: color, size: 18)
                    }
                    .buttonStyle(.plain)
                    Text(child.trimmedTitle)
                        .strikethrough(child.isCompleted)
                        .foregroundStyle(child.isCompleted ? .secondary : .primary)
                    Spacer()
                }
                .padding(.leading, 12)
            }
        }
        .padding(.vertical, 6)
        .onAppear { editingTitle = task.title }
        .onChange(of: task.title) { _, newValue in
            if !isEditing { editingTitle = newValue }
        }
        .contextMenu {
            Button(task.isCompleted ? "Mark Incomplete" : "Mark Complete") {
                Task { await session.toggle(task) }
            }
            Button("Delete", role: .destructive) {
                Task { await session.delete(task) }
            }
        }
    }

    @ViewBuilder
    private var metadata: some View {
        HStack(spacing: 8) {
            if let due = task.due {
                TaskDueText(date: due)
                    .font(.caption)
            }
            if let notes = task.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}
