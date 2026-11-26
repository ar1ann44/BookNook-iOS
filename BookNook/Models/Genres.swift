import Foundation

enum Genres {
    /// Stored values stay in English (they match the web app and work as
    /// Google Books subjects); `label(_:)` gives the Spanish name to show.
    static let all = [
        "Science Fiction", "Fantasy", "Magical Realism", "Classics", "Essay", "Poetry",
        "Mystery", "Thriller", "Romance", "Horror", "Non-fiction", "Historical Fiction",
        "Young Adult", "Biography", "Memoir", "Philosophy", "Drama", "Satire",
        "Short Stories", "Graphic Novels", "Dystopian", "Adventure", "Crime",
        "Contemporary Fiction", "Literary Fiction", "Self-help", "Travel", "Humor",
        "War", "Political Fiction", "Noir", "Mythology", "Psychology", "Fairy Tales",
    ]

    private static let spanish: [String: String] = [
        "Science Fiction": "Ciencia ficción",
        "Fantasy": "Fantasía",
        "Magical Realism": "Realismo mágico",
        "Classics": "Clásicos",
        "Essay": "Ensayo",
        "Poetry": "Poesía",
        "Mystery": "Misterio",
        "Thriller": "Suspenso",
        "Romance": "Romance",
        "Horror": "Terror",
        "Non-fiction": "No ficción",
        "Historical Fiction": "Ficción histórica",
        "Young Adult": "Juvenil",
        "Biography": "Biografía",
        "Memoir": "Memorias",
        "Philosophy": "Filosofía",
        "Drama": "Drama",
        "Satire": "Sátira",
        "Short Stories": "Cuentos",
        "Graphic Novels": "Novela gráfica",
        "Dystopian": "Distopía",
        "Adventure": "Aventura",
        "Crime": "Crimen",
        "Contemporary Fiction": "Ficción contemporánea",
        "Literary Fiction": "Ficción literaria",
        "Self-help": "Autoayuda",
        "Travel": "Viajes",
        "Humor": "Humor",
        "War": "Bélica",
        "Political Fiction": "Ficción política",
        "Noir": "Novela negra",
        "Mythology": "Mitología",
        "Psychology": "Psicología",
        "Fairy Tales": "Cuentos de hadas",
    ]

    static func label(_ genre: String) -> String {
        spanish[genre] ?? genre
    }
}
