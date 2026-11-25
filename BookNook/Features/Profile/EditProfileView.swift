import PhotosUI
import SwiftUI

struct EditProfileView: View {
    let store: ProfileStore

    @Environment(\.dismiss) private var dismiss
    @State private var bio: String
    @State private var genres: [String]
    @State private var topBooks: [Book?]
    @State private var photoItem: PhotosPickerItem?
    @State private var isUploadingPhoto = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var bookSlotToFill: BookSlot?

    private struct BookSlot: Identifiable {
        let id: Int
    }

    init(store: ProfileStore, profile: Profile) {
        self.store = store
        _bio = State(initialValue: profile.bio)
        _genres = State(initialValue: profile.genres)
        var slots: [Book?] = profile.topBooks.prefix(Profile.maxTopBooks).map { $0 }
        while slots.count < Profile.maxTopBooks { slots.append(nil) }
        _topBooks = State(initialValue: slots)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        let avatar = AvatarPickerLabel(
                            urlString: store.profile?.avatarUrl,
                            name: store.profile?.username ?? "?",
                            isUploading: isUploadingPhoto
                        )
                        PhotosPicker(selection: $photoItem, matching: .images) { avatar }
                            .disabled(isUploadingPhoto)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                Section("Bio") {
                    TextField("Tell other readers about yourself", text: $bio, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    if !genres.isEmpty {
                        FlowLayout {
                            ForEach(genres, id: \.self) { genre in
                                GenreChip(title: genre) {
                                    genres.removeAll { $0 == genre }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    NavigationLink("Choose genres") {
                        GenrePickerView(selection: $genres)
                    }
                } header: {
                    Text("Favorite genres")
                }

                Section {
                    ForEach(0..<Profile.maxTopBooks, id: \.self) { index in
                        bookSlotRow(index)
                    }
                } header: {
                    Text("Top 4 books")
                } footer: {
                    Text("Tap a slot to search Google Books.")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red).font(.footnote)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Edit profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save", action: save)
                    }
                }
            }
            .sheet(item: $bookSlotToFill) { slot in
                BookSearchView(title: "Favorite #\(slot.id + 1)") { book in
                    topBooks[slot.id] = book
                }
            }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task { await upload(item) }
            }
        }
    }

    @ViewBuilder
    private func bookSlotRow(_ index: Int) -> some View {
        if let book = topBooks[index] {
            HStack {
                BookRow(book: book)
                Button {
                    topBooks[index] = nil
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove \(book.title)")
            }
            .contentShape(Rectangle())
            .onTapGesture { bookSlotToFill = BookSlot(id: index) }
        } else {
            Button {
                bookSlotToFill = BookSlot(id: index)
            } label: {
                Label("Add favorite #\(index + 1)", systemImage: "plus")
            }
        }
    }

    private func upload(_ item: PhotosPickerItem) async {
        isUploadingPhoto = true
        errorMessage = nil
        defer {
            isUploadingPhoto = false
            photoItem = nil
        }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data)
            else {
                errorMessage = "Could not read that photo."
                return
            }
            try await store.uploadAvatar(image)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save() {
        isSaving = true
        errorMessage = nil
        Task {
            defer { isSaving = false }
            do {
                try await store.save(bio: bio, genres: genres, topBooks: topBooks.compactMap { $0 })
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

private struct GenrePickerView: View {
    @Binding var selection: [String]
    @State private var query = ""

    private var filtered: [String] {
        let q = query.trimmingCharacters(in: .whitespaces)
        return q.isEmpty ? Genres.all : Genres.all.filter { $0.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        List(filtered, id: \.self) { genre in
            Button {
                if let index = selection.firstIndex(of: genre) {
                    selection.remove(at: index)
                } else {
                    selection.append(genre)
                }
            } label: {
                HStack {
                    Text(genre).foregroundStyle(Theme.ink)
                    Spacer()
                    if selection.contains(genre) {
                        Image(systemName: "checkmark").foregroundStyle(Theme.midnight)
                    }
                }
            }
        }
        .searchable(text: $query, prompt: "Search genres")
        .navigationTitle("Genres")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AvatarPickerLabel: View {
    let urlString: String?
    let name: String
    let isUploading: Bool

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            AvatarView(urlString: urlString, name: name, size: 100)
                .overlay {
                    if isUploading {
                        Circle().fill(.black.opacity(0.4))
                        ProgressView().tint(.white)
                    }
                }
            Image(systemName: "camera.circle.fill")
                .font(.title)
                .foregroundStyle(.white, Theme.midnight)
        }
    }
}
