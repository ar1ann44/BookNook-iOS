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
                    TextField("http://192.168.1.10:4000", text: $address)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Server address")
                } footer: {
                    Text("In the simulator use http://localhost:4000. On your iPhone use your Mac's local IP address (System Settings › Wi‑Fi › Details) and keep both on the same Wi‑Fi network.")
                }

                Section {
                    Button(action: check) {
                        HStack {
                            Text("Test connection")
                            Spacer()
                            if isChecking { ProgressView() }
                        }
                    }
                    if let status {
                        Text(status).font(.footnote)
                    }
                }
            }
            .navigationTitle("Server")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
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
                status = "✅ Connected to the server."
            } catch {
                status = "❌ \(error.localizedDescription)"
            }
        }
    }
}
