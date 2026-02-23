//
//  InsightsData.swift
//  Aidoku
//
//  Created by Skitty on 12/20/25.
//

import Foundation

struct InsightsData {
    var currentStreak: Int
    var longestStreak: Int
    var heatmapData: HeatmapData
    var chartData: [YearlyMonthData]
    let statsData: [SmallStatData]
    var avgSessionMinutes: Int
    var readingHabits: ReadingHabitsData
    var topSeries: [TopSeriesEntry]
    var yearInReview: YearInReviewData

    init(
        currentStreak: Int = 0,
        longestStreak: Int = 0,
        heatmapData: HeatmapData = .empty(),
        chartData: [YearlyMonthData] = [],
        seriesTotal: Int = 0,
        seriesMonth: Int = 0,
        seriesYear: Int = 0,
        seriesPreviousMonth: Int = 0,
        hoursTotal: Int = 0,
        hoursMonth: Int = 0,
        hoursYear: Int = 0,
        hoursPreviousMonth: Int = 0,
        chaptersTotal: Int = 0,
        chaptersMonth: Int = 0,
        chaptersYear: Int = 0,
        chaptersPreviousMonth: Int = 0,
        avgSessionMinutes: Int = 0,
        readingHabits: ReadingHabitsData = .empty,
        topSeries: [TopSeriesEntry] = [],
        yearInReview: YearInReviewData = .empty
    ) {
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.heatmapData = heatmapData
        self.chartData = chartData
        self.avgSessionMinutes = avgSessionMinutes
        self.readingHabits = readingHabits
        self.topSeries = topSeries
        self.yearInReview = yearInReview
        self.statsData = [
            .init(
                total: chaptersTotal,
                thisMonth: chaptersMonth,
                thisYear: chaptersYear,
                previousMonth: chaptersPreviousMonth,
                subtitle: NSLocalizedString("CHAPTER_PLURAL"),
                singularSubtitle: NSLocalizedString("CHAPTER_SINGULAR")
            ),
            .init(
                total: seriesTotal,
                thisMonth: seriesMonth,
                thisYear: seriesYear,
                previousMonth: seriesPreviousMonth,
                subtitle: NSLocalizedString("SERIES_PLURAL"),
                singularSubtitle: NSLocalizedString("SERIES_SINGULAR")
            ),
            .init(
                total: hoursTotal,
                thisMonth: hoursMonth,
                thisYear: hoursYear,
                previousMonth: hoursPreviousMonth,
                subtitle: NSLocalizedString("HOUR_PLURAL"),
                singularSubtitle: NSLocalizedString("HOUR_SINGULAR")
            )
        ]
    }

    static func get() async -> InsightsData {
        await CoreDataManager.shared.container.performBackgroundTask { context in
            let (currentStreak, longestStreak) = CoreDataManager.shared.getStreakLengths(context: context)
            let basicStats = CoreDataManager.shared.getBasicStats(context: context)
            let chartData = CoreDataManager.shared.getChapterYearlyReadingData(context: context)
            let heatmapData = CoreDataManager.shared.getReadingHeatmapData()
            let chaptersStats = CoreDataManager.shared.getChaptersReadStats(context: context)
            let sessionStats = CoreDataManager.shared.getSessionStats(context: context)
            let readingHabits = CoreDataManager.shared.getReadingHabits(context: context)
            let topSeries = CoreDataManager.shared.getTopSeries(limit: 5, context: context)
            let yearInReview = CoreDataManager.shared.getYearInReviewData(context: context)
            return InsightsData(
                currentStreak: currentStreak,
                longestStreak: longestStreak,
                heatmapData: heatmapData,
                chartData: chartData,
                seriesTotal: basicStats.seriesTotal,
                seriesMonth: basicStats.seriesMonth,
                seriesYear: basicStats.seriesYear,
                seriesPreviousMonth: basicStats.seriesPreviousMonth,
                hoursTotal: basicStats.hoursTotal,
                hoursMonth: basicStats.hoursMonth,
                hoursYear: basicStats.hoursYear,
                hoursPreviousMonth: basicStats.hoursPreviousMonth,
                chaptersTotal: chaptersStats.total,
                chaptersMonth: chaptersStats.month,
                chaptersYear: chaptersStats.year,
                chaptersPreviousMonth: chaptersStats.previousMonth,
                avgSessionMinutes: sessionStats.avgMinutes,
                readingHabits: readingHabits,
                topSeries: topSeries,
                yearInReview: yearInReview
            )
        }
    }

    static let demoData: InsightsData = .init(
        currentStreak: 2,
        longestStreak: 3,
        heatmapData: .demo(),
        chartData: [
            .init(year: 2025, data: .init(
                january: 0,
                february: 0,
                march: 0,
                april: 0,
                may: 8,
                june: 0,
                july: 0,
                august: 0,
                september: 9,
                october: 0,
                november: 10,
                december: 1
            )),
            .init(year: 2024, data: .init(
                january: 1,
                february: 0,
                march: 0,
                april: 0,
                may: 8,
                june: 0,
                july: 0,
                august: 0,
                september: 0,
                october: 2,
                november: 7,
                december: 8
            ))
        ],
        seriesTotal: 4,
        seriesMonth: 0,
        seriesYear: 2,
        seriesPreviousMonth: 1,
        hoursTotal: 1,
        hoursMonth: 0,
        hoursYear: 1,
        hoursPreviousMonth: 0,
        chaptersTotal: 248,
        chaptersMonth: 12,
        chaptersYear: 180,
        chaptersPreviousMonth: 9,
        avgSessionMinutes: 23,
        readingHabits: .demo,
        topSeries: [],
        yearInReview: .demoData
    )
}
