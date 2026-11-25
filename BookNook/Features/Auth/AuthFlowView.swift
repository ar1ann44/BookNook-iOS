import SwiftUI

struct AuthFlowView: View {
    @State private var showingSignUp = false
    @State private var showingServerSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    VStack(spacing: 8) {
                        Image(systemName: "books.vertical.fill")
                            .font(.system(size: 52))
                            .foregroundStyle(Theme.moss)
                        Text("BookNook")
                            .font(Theme.heading(40))
                            .foregroundStyle(Theme.ink)
                        Text("Read together, one chapter at a time.")
                            .font(Theme.body)
                            .foregroundStyle(Theme.midnight)
                    }
                    .padding(.top, 48)

                    if showingSignUp {
                        SignUpForm(onSwitch: { withAnimation { showingSignUp = false } })
                    } else {
                        LoginForm(onSwitch: { withAnimation { showingSignUp = true } })
                    }
                }
                .padding(24)
            }
            .background(Theme.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingServerSettings = true
                    } label: {
                        Image(systemName: "server.rack")
                    }
                    .accessibilityLabel("Server settings")
                }
            }
            .sheet(isPresented: $showingServerSettings) {
                ServerSettingsView()
            }
        }
    }
}

private struct LoginForm: View {
    @Environment(SessionStore.self) private var session
    let onSwitch: () -> Void

    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 14) {
            Text("Log in")
                .font(Theme.heading(26))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)

            TextField("Email", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .fieldStyle()

            SecureField("Password", text: $password)
                .textContentType(.password)
                .fieldStyle()

            ErrorText(message: errorMessage)

            Button(action: submit) {
                if isLoading { ProgressView().tint(.white) } else { Text("Log in") }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isLoading || email.isEmpty || password.isEmpty)

            Button("Don't have an account? Sign up", action: onSwitch)
                .font(.subheadline)
                .padding(.top, 4)
        }
    }

    private func submit() {
        errorMessage = nil
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                try await session.logIn(email: email.trimmingCharacters(in: .whitespaces), password: password)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

private struct SignUpForm: View {
    @Environment(SessionStore.self) private var session
    let onSwitch: () -> Void

    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String?
    @State private var isLoading = false

    private var canSubmit: Bool {
        !username.isEmpty && !email.isEmpty && !password.isEmpty && !isLoading
    }

    var body: some View {
        VStack(spacing: 14) {
            Text("Create your account")
                .font(Theme.heading(26))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)

            TextField("Username", text: $username)
                .textContentType(.username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .fieldStyle()

            TextField("Email", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .fieldStyle()

            SecureField("Password", text: $password)
                .textContentType(.newPassword)
                .fieldStyle()

            SecureField("Confirm password", text: $confirmPassword)
                .textContentType(.newPassword)
                .fieldStyle()

            ErrorText(message: errorMessage)

            Button(action: submit) {
                if isLoading { ProgressView().tint(.white) } else { Text("Sign up") }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!canSubmit)

            Button("Already have an account? Log in", action: onSwitch)
                .font(.subheadline)
                .padding(.top, 4)
        }
    }

    private func submit() {
        errorMessage = nil
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match."
            return
        }
        guard password.count >= 6 else {
            errorMessage = "Use at least 6 characters for your password."
            return
        }
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                try await session.signUp(
                    username: username.trimmingCharacters(in: .whitespaces),
                    email: email.trimmingCharacters(in: .whitespaces),
                    password: password
                )
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct ErrorText: View {
    let message: String?

    var body: some View {
        if let message {
            Text(message)
                .font(.footnote)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
