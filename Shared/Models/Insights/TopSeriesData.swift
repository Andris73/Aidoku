//
//  TopSeriesData.swift
//  Aidoku
//
//  Created on 2025-01-01.
//

import Foundation

struct TopSeriesEntry: Identifiable {
    let id = UUID()
    let sourceId: String
    let mangaId: String
    let title: String
    let coverUrl: String?
    let chaptersRead: Int
    let sessionsCount: Int
    let hoursRead: Double

    var mangaIdentifier: MangaIdentifier {
        .init(sourceKey: sourceId, mangaKey: mangaId)
    }
}
