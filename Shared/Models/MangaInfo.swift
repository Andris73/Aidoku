//
//  MangaInfo.swift
//  Aidoku
//
//  Created by Skitty on 8/7/22.
//

import Foundation

struct MangaInfo: Sendable {
    var identifier: MangaIdentifier { .init(sourceKey: sourceId, mangaKey: mangaId) }

    let mangaId: String
    let sourceId: String

    var coverUrl: URL?
    var title: String?
    var author: String?

    var url: URL?

    var unread: Int = 0
    var downloads: Int = 0
    var hasNewerSource: Bool = false

    func toManga() -> Manga {
        Manga(
            sourceId: sourceId,
            id: mangaId,
            title: title,
            author: author,
            coverUrl: coverUrl,
            url: url
        )
    }
}

// MARK: - Hashable (identity = sourceId + mangaId only)
// Dynamic display fields (unread, downloads, hasNewerSource) are excluded
// so that NSDiffableDataSource treats changes to those fields as content
// updates to the *same* item rather than a delete + insert of a new item.
extension MangaInfo: Hashable {
    static func == (lhs: MangaInfo, rhs: MangaInfo) -> Bool {
        lhs.sourceId == rhs.sourceId && lhs.mangaId == rhs.mangaId
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(sourceId)
        hasher.combine(mangaId)
    }
}
