import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var session: SessionController

    var body: some View {
        List(selection: Binding(
            get: { session.selectedListId },
            set: { if let value = $0 { session.select(listId: value) } }
        )) {
            Section("My Lists") {
                ForEach(session.snapshot.lists) { list in
                    HStack(spacing: 10) {
                        ListGlyph(color: ListColor.color(for: list.id), size: 28)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(list.title)
                                .font(.body)
                            Text("\(list.incompleteTasks.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                    .tag(list.id)
                    .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Tasks")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                if session.isSyncing {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button {
                        Task { await session.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("Refresh from Google Tasks")
                    .disabled(!session.isSignedIn)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            AccountFooter()
                .padding(12)
        }
    }
}

struct AccountFooter: View {
    @EnvironmentObject private var session: SessionController

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if session.snapshot.isDemo {
                Text(session.isSignedIn
                     ? "Syncing sample data."
                     : "Showing sample tasks. Sign in to use your Google Tasks.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if session.isSignedIn {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Google Tasks")
                            .font(.caption.weight(.semibold))
                        Text(session.snapshot.accountEmail ?? "Signed in")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Button("Sign Out") { session.signOut() }
                        .controlSize(.small)
                }
            } else {
                Button {
                    Task { await session.signIn() }
                } label: {
                    if session.isSigningIn {
                        ProgressView()
                            .controlSize(.small)
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(session.isConfigured ? "Sign in with Google" : "Sign in unavailable")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!session.isConfigured || session.isSigningIn)
                .help(session.isConfigured ? "Connect your Google Tasks account" : "This build cannot sign in to Google.")
            }
        }
    }
}
