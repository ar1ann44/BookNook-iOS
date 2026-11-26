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
                    TextField("Name", text: $name)
                    TextField("What is this club about?", text: $description, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section {
                    Picker("Privacy", selection: $privacy) {
                        ForEach(ClubPrivacy.allCases) { option in
                            Label(option.label, systemImage: option.systemImage).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Who can join")
                } footer: {
                    Text(privacy == .public
                         ? "Anyone can find this club and join with one tap."
                         : "Only people with the invite code can join. You'll get the code after creating the club.")
                }

                Section("Current book") {
                    if let currentBook {
                        HStack {
                            BookRow(book: currentBook)
                            Button {
                                self.currentBook = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Remove current book")
                        }
                    } else {
                        Button("Choose a book", systemImage: "magnifyingglass") {
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
            .navigationTitle("New club")
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
            .sheet(isPresented: $showingBookSearch) {
                BookSearchView(title: "Current book") { currentBook = $0 }
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
