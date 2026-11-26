import SwiftUI

struct BookCoverView: View {
    let urlString: String?
    var title: String?
    var author: String?
    var width: CGFloat = 60

    var body: some View {
        AsyncImage(url: ServerConfig.resolve(urlString)) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
            } else if urlString != nil, phase.error == nil {
                Theme.locked
            } else {
                placeholder
            }
        }
        .frame(width: width, height: width * 1.5)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    @ViewBuilder
    private var placeholder: some View {
        if let title, !title.isEmpty {
            GeneratedCover(title: title, author: author, width: width)
        } else {
            ZStack {
                Theme.locked
                Image(systemName: "book.closed")
                    .foregroundStyle(Theme.moss)
            }
        }
    }
}

/// Stand-in cover for books that Google Books has no image for: a solid
/// color picked from the title, with the title and author printed on it.
private struct GeneratedCover: View {
    let title: String
    let author: String?
    let width: CGFloat

    private static let palette: [Color] = [Theme.ink, Theme.midnight, Theme.moss, Theme.rosy]

    private var color: Color {
        let seed = title.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0x7FFFFFFF }
        return Self.palette[seed % Self.palette.count]
    }

    private var isSmall: Bool { width < 60 }

    var body: some View {
        ZStack(alignment: .leading) {
            color
            Rectangle()
                .fill(.black.opacity(0.18))
                .frame(width: max(3, width * 0.06))
            VStack(alignment: .leading, spacing: width * 0.05) {
                Text(title)
                    .font(.system(size: max(7, width * 0.13), weight: .semibold, design: .serif))
                    .lineLimit(isSmall ? 3 : 5)
                    .minimumScaleFactor(0.7)
                if let author, !isSmall {
                    Spacer(minLength: 0)
                    Text(author)
                        .font(.system(size: max(6, width * 0.09)))
                        .lineLimit(2)
                        .opacity(0.85)
                }
            }
            .foregroundStyle(.white)
            .padding(.leading, width * 0.12)
            .padding([.trailing, .vertical], width * 0.08)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .accessibilityHidden(true)
    }
}

struct AvatarView: View {
    let urlString: String?
    let name: String
    var size: CGFloat = 96

    var body: some View {
        AsyncImage(url: ServerConfig.resolve(urlString)) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
            } else {
                ZStack {
                    Theme.moss
                    Text(name.prefix(1).uppercased())
                        .font(.system(size: size * 0.4, weight: .semibold, design: .serif))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}
