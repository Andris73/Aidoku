//
//  YearInReviewData.swift
//  Aidoku
//
//  Created on 2025-01-01.
//

import Foundation

struct YearInReviewData {
    let year: Int
    let mangaRead: Int
    let chaptersRead: Int
    let sessionsCount: Int
    let pagesRead: Int
    let hoursRead: Int
    let topMangaTitle: String?
    let topMangaCoverUrl: String?
    let topMangaPages: Int
    let topSourceName: String?
    let topSourceChapters: Int
    let topMonthName: String
    let topMonthChapters: Int

    var isEmpty: Bool {
        chaptersRead == 0 && sessionsCount == 0 && pagesRead == 0
    }

    static let empty = YearInReviewData(
        year: Calendar.current.component(.year, from: Date()),
        mangaRead: 0,
        chaptersRead: 0,
        sessionsCount: 0,
        pagesRead: 0,
        hoursRead: 0,
        topMangaTitle: nil,
        topMangaCoverUrl: nil,
        topMangaPages: 0,
        topSourceName: nil,
        topSourceChapters: 0,
        topMonthName: "",
        topMonthChapters: 0
    )

    static let demoData = YearInReviewData(
        year: 2025,
        mangaRead: 12,
        chaptersRead: 248,
        sessionsCount: 189,
        pagesRead: 4820,
        hoursRead: 36,
        topMangaTitle: "One Piece",
        topMangaCoverUrl: nil,
        topMangaPages: 1200,
        topSourceName: "MangaDex",
        topSourceChapters: 102,
        topMonthName: "November",
        topMonthChapters: 47
    )
}