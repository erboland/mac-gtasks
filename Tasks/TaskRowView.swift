import SwiftUI

struct TaskRowView: View {
    @EnvironmentObject private var session: SessionController
    var task: TaskItem
    var color: Color
    var subtasks: [TaskItem]
    @State private var editingTitle: String = ""
    @FocusState private var isEditing: Bool

    private var isCompleted: Bool { session.isVisuallyCompleted(task) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                checkbox(for: task, size: 22)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 2) {
                    if isEditing {
                        TextField("Task", text: $editingTitle)
                            .textFieldStyle(.plain)
                            .font(.system(size: 16))
                            .focused($isEditing)
                            .onSubmit { commitTitle() }
                            .onChange(of: isEditing) { _, focused in
                                if !focused { commitTitle() }
                            }
                    } else {
                        Text(task.trimmedTitle)
                            .font(.system(size: 16))
                            .foregroundStyle(isCompleted ? Color.secondary : Color.primary)
                            .overlay(alignment: .leading) {
                                GeometryReader { geo in
                                    Capsule()
                                        .fill(color.opacity(0.85))
                                        .frame(width: isCompleted ? geo.size.width : 0, height: 1.4)
                                        .frame(maxHeight: .infinity, alignment: .center)
                                }
                                .allowsHitTesting(false)
                            }
                            .animation(.easeInOut(duration: 0.32), value: isCompleted)
                            .onTapGesture { beginEditing() }
                    }

                    if !isCompleted {
                        metadata
                    }
                }
                Spacer(minLength: 0)
            }

            ForEach(subtasks) { child in
                HStack(spacing: 12) {
                    Spacer().frame(width: 22)
                    checkbox(for: child, size: 18)
                    Text(child.trimmedTitle)
                        .strikethrough(session.isVisuallyCompleted(child), color: color.opacity(0.8))
                        .foregroundStyle(session.isVisuallyCompleted(child) ? Color.secondary : Color.primary)
                        .animation(.easeInOut(duration: 0.32), value: session.isVisuallyCompleted(child))
                    Spacer()
                }
                .padding(.leading, 12)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onAppear { editingTitle = task.title }
        .onChange(of: task.title) { _, newValue in
            if !isEditing { editingTitle = newValue }
        }
        .contextMenu {
            Button(isCompleted ? "Mark Incomplete" : "Mark Complete") {
                session.toggle(task)
            }
            Button("Delete", role: .destructive) {
                Task { await session.delete(task) }
            }
        }
    }

    private func checkbox(for item: TaskItem, size: CGFloat) -> some View {
        Button {
            session.toggle(item)
        } label: {
            RemindersCheckbox(isCompleted: session.isVisuallyCompleted(item), color: color, size: size)
                .frame(width: max(28, size + 6), height: max(28, size + 6))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func beginEditing() {
        editingTitle = task.title
        isEditing = true
    }

    private func commitTitle() {
        let trimmed = editingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != task.title else {
            editingTitle = task.title
            return
        }
        Task { await session.rename(task, title: trimmed) }
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
