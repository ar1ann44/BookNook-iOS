import SwiftUI

struct JoinByCodeView: View {
    let onJoined: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var isJoining = false
    @State private var errorMessage: String?
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "key.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Theme.moss)
                Text("Únete a un club privado")
                    .font(Theme.heading(24))
                    .foregroundStyle(Theme.ink)
                Text("Escribe el código de 6 caracteres que te compartió el administrador del club.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                TextField("ABC123", text: $code)
                    .font(.system(.title2, design: .monospaced).weight(.semibold))
                    .multilineTextAlignment(.center)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .focused($focused)
                    .fieldStyle()
                    .onChange(of: code) { _, value in
                        code = String(value.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(6))
                    }

                ErrorText(message: errorMessage)

                Button(action: join) {
                    if isJoining { ProgressView().tint(.white) } else { Text("Unirme al club") }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(code.count < 6 || isJoining)

                Spacer()
            }
            .padding(24)
            .background(Theme.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.medium, .large])
    }

    private func join() {
        isJoining = true
        errorMessage = nil
        Task {
            defer { isJoining = false }
            do {
                let response = try await ClubService.join(code: code)
                dismiss()
                onJoined(response.id)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
