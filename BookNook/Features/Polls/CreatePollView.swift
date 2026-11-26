import SwiftUI

struct CreatePollView: View {
    let clubId: Int
    let onCreated: (CreatePollResponse) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var question = "What should we read next?"
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
                Section("Question") {
                    TextField("What should we read next?", text: $question, axis: .vertical)
                        .lineLimit(1...3)
                }

                Section {
                    ForEach(books, id: \.stableID) { book in
                        BookRow(book: book)
                    }
                    .onDelete { books.remove(atOffsets: $0) }

                    if books.count < Self.maxOptions {
                        Button("Add a book", systemImage: "plus") { showingSearch = true }
                    }
                } header: {
                    Text("Books (\(books.count)/\(Self.maxOptions))")
                } footer: {
                    Text("Pick between \(Self.minOptions) and \(Self.maxOptions) books. Swipe left on a book to remove it.")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).font(.footnote).foregroundStyle(.red)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("New poll")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Create", action: create).disabled(!canCreate)
                    }
                }
            }
            .sheet(isPresented: $showingSearch) {
                BookSearchView(title: "Add a book") { book in
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
