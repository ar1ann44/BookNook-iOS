import SwiftUI

struct CreateClubView: View {
    let onCreated: (Club) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var description = ""
    @State private var privacy: ClubPrivacy = .public
    @State private var currentBook: Book?
    @State private var showingBookSearch = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var canCreate: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !isSaving
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Club") {
                    TextField("Nombre", text: $name)
                    TextField("¿De qué trata este club?", text: $description, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section {
                    Picker("Privacidad", selection: $privacy) {
                        ForEach(ClubPrivacy.allCases) { option in
                            Label(option.label, systemImage: option.systemImage).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Quién puede unirse")
                } footer: {
                    Text(privacy == .public
                         ? "Cualquiera puede encontrar este club y unirse con un toque."
                         : "Solo pueden unirse personas con el código de invitación. Recibirás el código al crear el club.")
                }

                Section("Libro actual") {
                    if let currentBook {
                        HStack {
                            BookRow(book: currentBook)
                            Button {
                                self.currentBook = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Quitar libro actual")
                        }
                    } else {
                        Button("Elegir un libro", systemImage: "magnifyingglass") {
                            showingBookSearch = true
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).font(.footnote).foregroundStyle(.red)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Nuevo club")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Crear", action: create).disabled(!canCreate)
                    }
                }
            }
            .sheet(isPresented: $showingBookSearch) {
                BookSearchView(title: "Libro actual") { currentBook = $0 }
            }
        }
    }

    private func create() {
        isSaving = true
        errorMessage = nil
        Task {
            defer { isSaving = false }
            do {
                let club = try await ClubService.create(NewClub(
                    name: name.trimmingCharacters(in: .whitespaces),
                    description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                    privacy: privacy,
                    currentBook: currentBook
                ))
                dismiss()
                onCreated(club)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
