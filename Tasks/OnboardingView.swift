import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var session: SessionController
    @State private var page = 0

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch page {
                case 1: widgetPage
                case 2: signInPage
                default: welcomePage
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            footer
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .tint(ListColor.remindersOrange)
    }

    private var footer: some View {
        HStack(spacing: 16) {
            if page > 0 {
                Button("Back") {
                    withAnimation(.easeInOut(duration: 0.2)) { page -= 1 }
                }
                .buttonStyle(.plain)
            }
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(index == page ? ListColor.remindersOrange : Color.secondary.opacity(0.35))
                        .frame(width: 8, height: 8)
                }
            }
            Spacer()
            if page < 2 {
                Button(page == 0 ? "Continue" : "Next") {
                    withAnimation(.easeInOut(duration: 0.25)) { page += 1 }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding(.horizontal, 36)
        .padding(.bottom, 28)
        .padding(.top, 8)
    }

    private var welcomePage: some View {
        OnboardingPage(
            symbol: "rectangle.stack.fill",
            title: "Tasks lives on your desktop",
            message: "This is primarily a widget. Check Google Tasks off from the desktop or Notification Center — the window is there when you need lists, search, and new reminders."
        ) {
            WidgetPreviewCard()
                .frame(width: 280)
        }
    }

    private var widgetPage: some View {
        OnboardingPage(
            symbol: "plus.rectangle.on.rectangle",
            title: "Add the widget once",
            message: "After you sign in, macOS can show your lists on the desktop. You can also add it from Notification Center."
        ) {
            VStack(alignment: .leading, spacing: 12) {
                OnboardingStep(number: 1, text: "Control-click the desktop, then choose Edit Widgets.")
                OnboardingStep(number: 2, text: "Search for Tasks and add List.")
                OnboardingStep(number: 3, text: "Pick a size. Click the title later to switch lists.")
            }
            .frame(maxWidth: 420)
        }
    }

    private var signInPage: some View {
        OnboardingPage(
            symbol: "person.crop.circle.badge.checkmark",
            title: "Connect Google Tasks",
            message: "Sign in so the widget and this app stay in sync with the same lists."
        ) {
            VStack(spacing: 12) {
                Button {
                    Task { await session.signInFromOnboarding() }
                } label: {
                    if session.isSigningIn {
                        ProgressView()
                            .controlSize(.small)
                            .frame(maxWidth: 260)
                            .padding(.vertical, 4)
                    } else {
                        Text("Sign in with Google")
                            .frame(maxWidth: 260)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(session.isSigningIn || !session.isConfigured)

                if let error = session.errorMessage, !error.isEmpty {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 360)
                }

                if !session.isConfigured {
                    Text("This build is missing a Google OAuth client, so sign-in is unavailable.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 360)
                }

                Button("Continue with sample tasks") {
                    session.completeOnboarding()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .disabled(session.isSigningIn)
            }
        }
    }
}

private struct OnboardingPage<Extra: View>: View {
    var symbol: String
    var title: String
    var message: String
    @ViewBuilder var extra: Extra

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 24)
            Image(systemName: symbol)
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(ListColor.remindersOrange)
                .symbolRenderingMode(.hierarchical)
            Text(title)
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)
            Text(message)
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 460)
            extra
                .padding(.top, 8)
            Spacer(minLength: 12)
        }
        .padding(.horizontal, 40)
    }
}

private struct OnboardingStep: View {
    var number: Int
    var text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(ListColor.remindersOrange, in: Circle())
            Text(text)
                .font(.body)
                .foregroundStyle(.primary)
        }
    }
}

private struct WidgetPreviewCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ListGlyph(color: ListColor.remindersOrange, size: 22)
                Text("My Tasks")
                    .font(.headline)
                Spacer()
                Image(systemName: "plus")
                    .foregroundStyle(.secondary)
            }
            previewRow("Review the weekly plan", done: false)
            previewRow("Reply to design notes", done: false)
            previewRow("Buy oat milk", done: true)
        }
        .padding(16)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.separator.opacity(0.5), lineWidth: 1)
        }
    }

    private func previewRow(_ title: String, done: Bool) -> some View {
        HStack(spacing: 8) {
            RemindersCheckbox(isCompleted: done, color: ListColor.remindersOrange, size: 16)
            Text(title)
                .font(.callout)
                .foregroundStyle(done ? Color.secondary : Color.primary)
                .strikethrough(done, color: ListColor.remindersOrange.opacity(0.8))
        }
    }
}
