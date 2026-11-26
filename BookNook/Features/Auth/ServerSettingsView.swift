import SwiftUI

struct ServerSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var address = ServerConfig.baseURLString
    @State private var status: String?
    @State private var isChecking = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("http://Mi-Mac.local:4000", text: $address)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Dirección del servidor")
                } footer: {
                    Text("En el simulador usa http://localhost:4000. En tu iPhone usa el nombre de tu Mac terminado en .local, por ejemplo http://Mi-Mac.local:4000: sigue funcionando aunque cambie la IP. Lo encuentras en Ajustes del Sistema › General › Compartir › Nombre del host local. El iPhone y la Mac deben estar en la misma red Wi‑Fi.")
                }

                Section {
                    Button(action: check) {
                        HStack {
                            Text("Probar conexión")
                            Spacer()
                            if isChecking { ProgressView() }
                        }
                    }
                    if let status {
                        Text(status).font(.footnote)
                    }
                }
            }
            .navigationTitle("Servidor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        ServerConfig.baseURLString = address
                        dismiss()
                    }
                }
            }
        }
    }

    private func check() {
        let previous = ServerConfig.baseURLString
        ServerConfig.baseURLString = address
        isChecking = true
        status = nil
        Task {
            defer {
                isChecking = false
                ServerConfig.baseURLString = previous
            }
            do {
                let _: [Book] = try await APIClient.shared.request(.get, "api/books/search", authorized: false)
                status = "✅ Conectado al servidor."
            } catch {
                status = "❌ \(error.localizedDescription)"
            }
        }
    }
}
