import SwiftUI

struct EditClubView: View {
    let club: Club
    let onSaved: (Club) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var description: String
    @State private var currentBook: Book?
    @State private var showingBookSearch = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(club: Club, onSaved: @escaping (Club) -> Void) {
        self.club = club
        self.onSaved = onSaved
        _name = State(initialValue: club.name)
        _description = State(initialValue: club.description)
        _currentBook = State(initialValue: club.currentBook)
    }

    private var canSave: Bool {
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
                        Button("Cambiar libro", systemImage: "arrow.triangle.2.circlepath") {
                            showingBookSearch = true
                        }
                    } else {
                        Button("Elegir un libro", systemImage: "magnifyingglass") {
                            showingBookSearch = true
                        }
                    }
                } header: {
                    Text("Libro actual")
                }

                Section {
                    Label(club.privacy == .public ? "Club público" : "Club privado",
                          systemImage: club.privacy.systemImage)
                        .foregroundStyle(.secondary)
                } footer: {
                    Text("La privacidad se elige al crear el club y no se puede cambiar.")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).font(.footnote).foregroundStyle(.red)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Editar club")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Guardar", action: save).disabled(!canSave)
                    }
                }
            }
            .sheet(isPresented: $showingBookSearch) {
                BookSearchView(title: "Libro actual") { currentBook = $0 }
            }
        }
    }

    private func save() {
        isSaving = true
        errorMessage = nil
        Task {
            defer { isSaving = false }
            do {
                let saved = try await ClubService.update(
                    clubId: club.id,
                    name: name.trimmingCharacters(in: .whitespaces),
                    description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                    currentBook: currentBook
                )
                dismiss()
                onSaved(saved)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
