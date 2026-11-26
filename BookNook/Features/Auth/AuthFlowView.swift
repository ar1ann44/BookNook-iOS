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
                        Text("Leamos juntos, un capítulo a la vez.")
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
                    .accessibilityLabel("Configuración del servidor")
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
            Text("Iniciar sesión")
                .font(Theme.heading(26))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)

            TextField("Correo electrónico", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .fieldStyle()

            SecureField("Contraseña", text: $password)
                .textContentType(.password)
                .fieldStyle()

            ErrorText(message: errorMessage)

            Button(action: submit) {
                if isLoading { ProgressView().tint(.white) } else { Text("Entrar") }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isLoading || email.isEmpty || password.isEmpty)

            Button("¿No tienes cuenta? Regístrate", action: onSwitch)
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
            Text("Crea tu cuenta")
                .font(Theme.heading(26))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)

            TextField("Nombre de usuario", text: $username)
                .textContentType(.username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .fieldStyle()

            TextField("Correo electrónico", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .fieldStyle()

            SecureField("Contraseña", text: $password)
                .textContentType(.newPassword)
                .fieldStyle()

            SecureField("Confirmar contraseña", text: $confirmPassword)
                .textContentType(.newPassword)
                .fieldStyle()

            ErrorText(message: errorMessage)

            Button(action: submit) {
                if isLoading { ProgressView().tint(.white) } else { Text("Crear cuenta") }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!canSubmit)

            Button("¿Ya tienes cuenta? Inicia sesión", action: onSwitch)
                .font(.subheadline)
                .padding(.top, 4)
        }
    }

    private func submit() {
        errorMessage = nil
        guard password == confirmPassword else {
            errorMessage = "Las contraseñas no coinciden."
            return
        }
        guard password.count >= 6 else {
            errorMessage = "Usa al menos 6 caracteres en tu contraseña."
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
