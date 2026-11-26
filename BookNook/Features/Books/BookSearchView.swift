import SwiftUI

/// Sheet that searches Google Books through the server and returns the chosen book.
struct BookSearchView: View {
    var title = "Buscar un libro"
    let onSelect: (Book) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [Book] = []
    @State private var isSearching = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
                ForEach(results, id: \.stableID) { book in
                    Button {
                        onSelect(book)
                        dismiss()
                    } label: {
                        BookRow(book: book)
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.plain)
            .overlay {
                if isSearching {
                    ProgressView()
                } else if results.isEmpty, errorMessage == nil {
                    ContentUnavailableView(
                        query.isEmpty ? "Busca por título o autor" : "No se encontraron libros",
                        systemImage: "magnifyingglass"
                    )
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Título, autor o ISBN")
            .task(id: query) { await search() }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }

    private func search() async {
        let current = query
        guard !current.trimmingCharacters(in: .whitespaces).isEmpty else {
            results = []
            errorMessage = nil
            return
        }
        try? await Task.sleep(for: .milliseconds(400))
        guard !Task.isCancelled else { return }

        isSearching = true
        defer { isSearching = false }
        do {
            let found = try await BookService.search(current)
            guard !Task.isCancelled else { return }
            results = found
            errorMessage = nil
        } catch {
            guard !Task.isCancelled else { return }
            results = []
            errorMessage = error.localizedDescription
        }
    }
}

struct BookRow: View {
    let book: Book

    var body: some View {
        HStack(spacing: 12) {
            BookCoverView(urlString: book.coverUrl, title: book.title, author: book.author, width: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(Theme.body.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                Text(book.author)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let year = book.publishedDate?.prefix(4), !year.isEmpty {
                    Text(year)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
