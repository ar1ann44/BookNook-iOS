import SwiftUI

struct BookCoverView: View {
    let urlString: String?
    var width: CGFloat = 60

    var body: some View {
        AsyncImage(url: ServerConfig.resolve(urlString)) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
            } else {
                ZStack {
                    Theme.locked
                    Image(systemName: "book.closed")
                        .foregroundStyle(Theme.moss)
                }
            }
        }
        .frame(width: width, height: width * 1.5)
        .clipShape(RoundedRectangle(cornerRadius: 6))
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
                        .font(Theme.heading(size * 0.4))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}
