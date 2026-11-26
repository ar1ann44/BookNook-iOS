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

                    Button {
                        showingServerSettings = true
                    } label: {
                        Label("Configurar servidor", systemImage: "gearshape")
                            .font(.footnote)
                            .foregroundStyle(Theme.ink.opacity(0.55))
                    }
                    .padding(.top, 12)
                }
                .padding(24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.background.ignoresSafeArea())
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
    @FocusState private var focus: Field?

    private enum Field { case email, password }

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
                .submitLabel(.next)
                .focused($focus, equals: .email)
                .onSubmit { focus = .password }
                .fieldStyle()

            PasswordField(title: "Contraseña", text: $password, contentType: .password)
                .submitLabel(.go)
                .focused($focus, equals: .password)
                .onSubmit { if canSubmit { submit() } }

            ErrorText(message: errorMessage)

            Button(action: submit) {
                if isLoading { ProgressView().tint(.white) } else { Text("Entrar") }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!canSubmit)

            Button("¿No tienes cuenta? Regístrate", action: onSwitch)
                .font(.subheadline)
                .padding(.top, 4)
        }
    }

    private var canSubmit: Bool {
        !isLoading && !email.isEmpty && !password.isEmpty
    }

    private func submit() {
        errorMessage = nil
        focus = nil
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
    @FocusState private var focus: Field?

    private enum Field { case username, email, password, confirm }

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
                .submitLabel(.next)
                .focused($focus, equals: .username)
                .onSubmit { focus = .email }
                .fieldStyle()

            TextField("Correo electrónico", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.next)
                .focused($focus, equals: .email)
                .onSubmit { focus = .password }
                .fieldStyle()

            PasswordField(title: "Contraseña (mínimo 6 caracteres)", text: $password, contentType: .newPassword)
                .submitLabel(.next)
                .focused($focus, equals: .password)
                .onSubmit { focus = .confirm }

            PasswordField(title: "Confirmar contraseña", text: $confirmPassword, contentType: .newPassword)
                .submitLabel(.go)
                .focused($focus, equals: .confirm)
                .onSubmit { if canSubmit { submit() } }

            if !confirmPassword.isEmpty && confirmPassword != password {
                Text("Las contraseñas no coinciden.")
                    .font(.footnote)
                    .foregroundStyle(Theme.rosy)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

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

/// Secure field with a button to show or hide what was typed.
struct PasswordField: View {
    let title: String
    @Binding var text: String
    var contentType: UITextContentType = .password

    @State private var isRevealed = false

    var body: some View {
        HStack(spacing: 8) {
            Group {
                if isRevealed {
                    TextField(title, text: $text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } else {
                    SecureField(title, text: $text)
                }
            }
            .textContentType(contentType)

            Button {
                isRevealed.toggle()
            } label: {
                Image(systemName: isRevealed ? "eye.slash" : "eye")
                    .foregroundStyle(Theme.ink.opacity(0.5))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isRevealed ? "Ocultar contraseña" : "Mostrar contraseña")
        }
        .fieldStyle()
    }
}
