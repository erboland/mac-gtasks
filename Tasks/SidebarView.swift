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
                    NavigationLink(value: list.id) {
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
                    }
                    .tag(list.id)
                    .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Tasks")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    Task { await session.refresh() }
                } label: {
                    Image(systemName: session.isSyncing ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                }
                .help("Refresh from Google Tasks")
                .disabled(session.isSyncing || !session.isSignedIn)
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
                Text(session.isConfigured ? "Showing sample tasks until you sign in." : "Demo list — add a Google OAuth client to sync.")
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
                    Text(session.isConfigured ? "Sign in with Google" : "Sign in unavailable")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!session.isConfigured)
                .help(session.isConfigured ? "Connect your Google Tasks account" : "Set your client ID in GoogleAuthConfig.swift")
            }
        }
    }
}
