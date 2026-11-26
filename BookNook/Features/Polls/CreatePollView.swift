import SwiftUI

struct CreatePollView: View {
    let clubId: Int
    let onCreated: (CreatePollResponse) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var question = "¿Qué leemos después?"
    @State private var books: [Book] = []
    @State private var showingSearch = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    private static let minOptions = 2
    private static let maxOptions = 4

    private var canCreate: Bool {
        !question.trimmingCharacters(in: .whitespaces).isEmpty
            && books.count >= Self.minOptions
            && !isSaving
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Pregunta") {
                    TextField("¿Qué leemos después?", text: $question, axis: .vertical)
                        .lineLimit(1...3)
                }

                Section {
                    ForEach(books, id: \.stableID) { book in
                        BookRow(book: book)
                    }
                    .onDelete { books.remove(atOffsets: $0) }

                    if books.count < Self.maxOptions {
                        Button("Agregar un libro", systemImage: "plus") { showingSearch = true }
                    }
                } header: {
                    Text("Libros (\(books.count)/\(Self.maxOptions))")
                } footer: {
                    Text("Elige entre \(Self.minOptions) y \(Self.maxOptions) libros. Desliza un libro a la izquierda para quitarlo.")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).font(.footnote).foregroundStyle(.red)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Nueva encuesta")
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
            .sheet(isPresented: $showingSearch) {
                BookSearchView(title: "Agregar un libro") { book in
                    guard !books.contains(where: { $0.stableID == book.stableID }) else { return }
                    books.append(book)
                }
            }
        }
    }

    private func create() {
        isSaving = true
        errorMessage = nil
        Task {
            defer { isSaving = false }
            do {
                let response = try await ChannelService.createPoll(
                    clubId: clubId,
                    question: question.trimmingCharacters(in: .whitespacesAndNewlines),
                    books: books
                )
                dismiss()
                onCreated(response)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
