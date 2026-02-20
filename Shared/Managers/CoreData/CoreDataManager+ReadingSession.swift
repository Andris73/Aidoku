//
//  CoreDataManager+ReadingSession.swift
//  Aidoku
//
//  Created by Skitty on 12/16/25.
//

import CoreData
import Foundation

extension CoreDataManager {
    /// Remove all reading session objects.
    func clearSessions(context: NSManagedObjectContext? = nil) {
        clear(request: ReadingSessionObject.fetchRequest(), context: context)
    }

    /// Gets all reading session objects.
    func getSessions(context: NSManagedObjectContext? = nil) -> [ReadingSessionObject] {
        (try? (context ?? self.context).fetch(ReadingSessionObject.fetchRequest())) ?? []
    }

    func createSession(
        chapterIdentifier: ChapterIdentifier,
        data: HistoryManager.ReadingSessionData,
        context: NSManagedObjectContext? = nil
    ) {
        let historyObject = self.getOrCreateHistory(
            sourceId: chapterIdentifier.sourceKey,
            mangaId: chapterIdentifier.mangaKey,
            chapterId: chapterIdentifier.chapterKey,
            context: context
        )
        if historyObject.dateRead == .distantPast {
            // if history object was just created, populate it with info we have
            historyObject.dateRead = data.endDate
        }
        let session = ReadingSessionObject(context: context ?? self.context)
        session.startDate = data.startDate
        session.endDate = data.endDate
        session.pagesRead = Int16(data.pagesRead)
        session.history = historyObject
    }

    // get longest and current count of consecutive days with reading sessions
    func getStreakLengths(context: NSManagedObjectContext? = nil) -> (current: Int, longest: Int) {
        let context = context ?? self.context

        let fetchRequest = NSFetchRequest<NSDictionary>(entityName: "ReadingSession")
        fetchRequest.resultType = .dictionaryResultType
        fetchRequest.propertiesToFetch = ["endDate"]
        let results = try? context.fetch(fetchRequest)
        guard let results else { return (0, 0) }

        // get all unique days with a reading session
        let calendar = Calendar.current
        let daysSet = Set(results.compactMap { dict in
            (dict["endDate"] as? Date).map { calendar.startOfDay(for: $0) }
        })
        let days = Array(daysSet).sorted()

        // need at least two days to constitute a streak
        guard days.count >= 2 else { return (0, 0) }
        var current = 1
        var longest = 1

        for i in 1..<days.count {
            let prev = days[i - 1]
            let curr = days[i]
            let diff = calendar.dateComponents([.day], from: prev, to: curr).day ?? 0
            if diff == 1 {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }

        // ensure current streak last day is today or yesterday
        let today = calendar.startOfDay(for: Date.now)
        let lastDay = days.last!
        let diff = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0
        let isCurrent = (diff == 0 || diff == 1) && longest >= 2

        return (
            current: isCurrent ? current : 0,
            longest: longest >= 2 ? longest : 0
        )
    }

    struct BasicStats {
        var pagesTotal: Int = 0
        var pagesMonth: Int = 0
        var pagesYear: Int = 0
        var pagesPreviousMonth: Int = 0
        var seriesTotal: Int = 0
        var seriesMonth: Int = 0
        var seriesYear: Int = 0
        var seriesPreviousMonth: Int = 0
        var hoursTotal: Int = 0
        var hoursMonth: Int = 0
        var hoursYear: Int = 0
        var hoursPreviousMonth: Int = 0
    }

    // get page, series, and hour read counts (total, current month, and current year)
    func getBasicStats(context: NSManagedObjectContext?) -> BasicStats {
        let context = context ?? self.context

        let fetchRequest = NSFetchRequest<NSDictionary>(entityName: "ReadingSession")
        fetchRequest.resultType = .dictionaryResultType
        fetchRequest.propertiesToFetch = [
            "pagesRead", "startDate", "endDate",
            "history.sourceId",
            "history.mangaId"
        ]

        guard let results = try? context.fetch(fetchRequest) else {
            return .init()
        }

        let calendar = Calendar.current
        let now = Date()
        let currentYear = calendar.component(.year, from: now)
        let currentMonth = calendar.component(.month, from: now)

        let prevMonthDate = calendar.date(byAdding: .month, value: -1, to: now)!
        let prevMonthNum = calendar.component(.month, from: prevMonthDate)
        let prevMonthYear = calendar.component(.year, from: prevMonthDate)

        var pagesTotal = 0, pagesMonth = 0, pagesYear = 0, pagesPrevMonth = 0
        var durationTotal: Double = 0, durationMonth: Double = 0, durationYear: Double = 0, durationPrevMonth: Double = 0

        var seriesTotalSet = Set<MangaIdentifier>()
        var seriesMonthSet = Set<MangaIdentifier>()
        var seriesYearSet = Set<MangaIdentifier>()
        var seriesPrevMonthSet = Set<MangaIdentifier>()

        for dict in results {
            guard
                let pagesRead = dict["pagesRead"] as? Int,
                let startDate = dict["startDate"] as? Date,
                let endDate = dict["endDate"] as? Date,
                let sourceId = dict["history.sourceId"] as? String,
                let mangaId = dict["history.mangaId"] as? String
            else { continue }

            let duration = endDate.timeIntervalSince(startDate)
            let year = calendar.component(.year, from: endDate)
            let month = calendar.component(.month, from: endDate)
            let seriesKey = MangaIdentifier(sourceKey: sourceId, mangaKey: mangaId)

            pagesTotal += pagesRead
            durationTotal += duration
            seriesTotalSet.insert(seriesKey)

            if year == currentYear {
                pagesYear += pagesRead
                durationYear += duration
                seriesYearSet.insert(seriesKey)

                if month == currentMonth {
                    pagesMonth += pagesRead
                    durationMonth += duration
                    seriesMonthSet.insert(seriesKey)
                }
            }

            if year == prevMonthYear && month == prevMonthNum {
                pagesPrevMonth += pagesRead
                durationPrevMonth += duration
                seriesPrevMonthSet.insert(seriesKey)
            }
        }

        return BasicStats(
            pagesTotal: pagesTotal,
            pagesMonth: pagesMonth,
            pagesYear: pagesYear,
            pagesPreviousMonth: pagesPrevMonth,
            seriesTotal: seriesTotalSet.count,
            seriesMonth: seriesMonthSet.count,
            seriesYear: seriesYearSet.count,
            seriesPreviousMonth: seriesPrevMonthSet.count,
            hoursTotal: Int(durationTotal / 3600),
            hoursMonth: Int(durationMonth / 3600),
            hoursYear: Int(durationYear / 3600),
            hoursPreviousMonth: Int(durationPrevMonth / 3600)
        )
    }

    func getChapterYearlyReadingData(context: NSManagedObjectContext? = nil) -> [YearlyMonthData] {
        let context = context ?? self.context

        let fetchRequest = NSFetchRequest<NSDictionary>(entityName: "ReadingSession")
        fetchRequest.resultType = .dictionaryResultType
        fetchRequest.propertiesToFetch = [
            "endDate",
            "pagesRead",
            "history.sourceId",
            "history.mangaId",
            "history.chapterId",
            "history.total",
            "history.completed"
        ]

        guard let results = try? context.fetch(fetchRequest) else { return [] }

        // group reading sessions by chapter, year, and month
        struct ChapterMonthKey: Hashable {
            let chapterId: ChapterIdentifier
            let year: Int
            let month: Int
            let totalPageCount: Int?
            let isCompleted: Bool
        }

        var chapterMonthSessions: [ChapterMonthKey: Int] = [:] // sum of pagesRead
        let calendar = Calendar.current

        for dict in results {
            guard
                let endDate = dict["endDate"] as? Date,
                let sourceId = dict["history.sourceId"] as? String,
                let mangaId = dict["history.mangaId"] as? String,
                let chapterId = dict["history.chapterId"] as? String,
                let pagesRead = dict["pagesRead"] as? Int
            else { continue }

            let comps = calendar.dateComponents([.year, .month], from: endDate)
            guard let year = comps.year, let month = comps.month else { continue }

            let totalPageCount = dict["history.total"] as? Int
            let isCompleted = dict["history.completed"] as? Bool ?? false

            let key = ChapterMonthKey(
                chapterId: .init(sourceKey: sourceId, mangaKey: mangaId, chapterKey: chapterId),
                year: year,
                month: month,
                totalPageCount: totalPageCount,
                isCompleted: isCompleted
            )
            chapterMonthSessions[key, default: 0] += pagesRead
        }

        // determine chapter read counts per month and year
        var yearlyMonthChapters: [Int: [Int: Int]] = [:] // [year: [month: readCount]]

        for (key, totalPagesRead) in chapterMonthSessions {
            let isRead: Bool
            if let totalPageCount = key.totalPageCount {
                // if history has total page count, check that we've read enough pages to complete the chapter
                isRead = totalPagesRead >= totalPageCount
            } else {
                // fallback: if history is marked completed, consider read
                isRead = key.isCompleted
            }
            if isRead {
                yearlyMonthChapters[key.year, default: [:]][key.month, default: 0] += 1
            }
        }

        let sortedYears = yearlyMonthChapters.keys.sorted()
        var result: [YearlyMonthData] = []

        for year in sortedYears {
            let data = MonthData(
                january: yearlyMonthChapters[year]?[1] ?? 0,
                february: yearlyMonthChapters[year]?[2] ?? 0,
                march: yearlyMonthChapters[year]?[3] ?? 0,
                april: yearlyMonthChapters[year]?[4] ?? 0,
                may: yearlyMonthChapters[year]?[5] ?? 0,
                june: yearlyMonthChapters[year]?[6] ?? 0,
                july: yearlyMonthChapters[year]?[7] ?? 0,
                august: yearlyMonthChapters[year]?[8] ?? 0,
                september: yearlyMonthChapters[year]?[9] ?? 0,
                october: yearlyMonthChapters[year]?[10] ?? 0,
                november: yearlyMonthChapters[year]?[11] ?? 0,
                december: yearlyMonthChapters[year]?[12] ?? 0
            )
            result.append(.init(year: year, data: data))
        }

        return result
    }

    // MARK: - Chapters Read Stats

    func getChaptersReadStats(
        context: NSManagedObjectContext? = nil
    ) -> (total: Int, month: Int, year: Int, previousMonth: Int) {
        let context = context ?? self.context
        let request = NSFetchRequest<NSDictionary>(entityName: "History")
        request.resultType = .dictionaryResultType
        request.predicate = NSPredicate(format: "completed == true")
        request.propertiesToFetch = ["dateRead"]

        guard let results = try? context.fetch(request) else { return (0, 0, 0, 0) }

        let calendar = Calendar.current
        let now = Date()
        let currentYear = calendar.component(.year, from: now)
        let currentMonth = calendar.component(.month, from: now)
        let prevDate = calendar.date(byAdding: .month, value: -1, to: now)!
        let prevMonthNum = calendar.component(.month, from: prevDate)
        let prevMonthYear = calendar.component(.year, from: prevDate)

        var total = 0, month = 0, year = 0, previousMonth = 0

        for dict in results {
            total += 1
            guard let dateRead = dict["dateRead"] as? Date else { continue }
            let y = calendar.component(.year, from: dateRead)
            let m = calendar.component(.month, from: dateRead)

            if y == currentYear {
                year += 1
                if m == currentMonth { month += 1 }
            }
            if y == prevMonthYear && m == prevMonthNum { previousMonth += 1 }
        }

        return (total, month, year, previousMonth)
    }

    // MARK: - Session Stats (count + average duration)

    func getSessionStats(
        context: NSManagedObjectContext? = nil
    ) -> (count: Int, avgMinutes: Int) {
        let context = context ?? self.context
        let request = NSFetchRequest<NSDictionary>(entityName: "ReadingSession")
        request.resultType = .dictionaryResultType
        request.propertiesToFetch = ["startDate", "endDate"]

        guard let results = try? context.fetch(request) else { return (0, 0) }

        var totalDuration: Double = 0
        var count = 0

        for dict in results {
            guard let start = dict["startDate"] as? Date,
                  let end = dict["endDate"] as? Date
            else { continue }
            totalDuration += end.timeIntervalSince(start)
            count += 1
        }

        let avg = count > 0 ? Int(totalDuration / Double(count) / 60) : 0
        return (count, avg)
    }

    // MARK: - Reading Habits (time-of-day + day-of-week)

    func getReadingHabits(context: NSManagedObjectContext? = nil) -> ReadingHabitsData {
        let context = context ?? self.context
        let request = NSFetchRequest<NSDictionary>(entityName: "ReadingSession")
        request.resultType = .dictionaryResultType
        request.propertiesToFetch = ["endDate"]

        guard let results = try? context.fetch(request) else { return .empty }

        let calendar = Calendar.current
        var timeOfDay = [0, 0, 0, 0]
        var dayOfWeek = [0, 0, 0, 0, 0, 0, 0]

        for dict in results {
            guard let date = dict["endDate"] as? Date else { continue }
            let hour = calendar.component(.hour, from: date)
            let weekday = calendar.component(.weekday, from: date)

            let bucket = TimeOfDayBucket.bucket(forHour: hour)
            timeOfDay[bucket.rawValue] += 1

            let day = DayOfWeek.from(calendarWeekday: weekday)
            dayOfWeek[day.rawValue] += 1
        }

        return ReadingHabitsData(timeOfDay: timeOfDay, dayOfWeek: dayOfWeek)
    }

    // MARK: - Top Series

    func getTopSeries(limit: Int = 5, context: NSManagedObjectContext? = nil) -> [TopSeriesEntry] {
        let context = context ?? self.context
        let request = NSFetchRequest<NSDictionary>(entityName: "ReadingSession")
        request.resultType = .dictionaryResultType
        request.propertiesToFetch = [
            "pagesRead", "startDate", "endDate",
            "history.sourceId", "history.mangaId"
        ]

        guard let results = try? context.fetch(request) else { return [] }

        struct MangaStats {
            var pages: Int = 0
            var sessions: Int = 0
            var duration: Double = 0
        }

        var statsMap: [MangaIdentifier: MangaStats] = [:]

        for dict in results {
            guard let pages = dict["pagesRead"] as? Int,
                  let start = dict["startDate"] as? Date,
                  let end = dict["endDate"] as? Date,
                  let sourceId = dict["history.sourceId"] as? String,
                  let mangaId = dict["history.mangaId"] as? String
            else { continue }

            let key = MangaIdentifier(sourceKey: sourceId, mangaKey: mangaId)
            statsMap[key, default: MangaStats()].pages += pages
            statsMap[key, default: MangaStats()].sessions += 1
            statsMap[key, default: MangaStats()].duration += end.timeIntervalSince(start)
        }

        let sorted = statsMap.sorted { $0.value.pages > $1.value.pages }

        return sorted.prefix(limit).map { identifier, stats in
            let manga = self.getManga(
                sourceId: identifier.sourceKey,
                mangaId: identifier.mangaKey,
                context: context
            )
            return TopSeriesEntry(
                sourceId: identifier.sourceKey,
                mangaId: identifier.mangaKey,
                title: manga?.title ?? identifier.mangaKey,
                coverUrl: manga?.cover,
                pagesRead: stats.pages,
                sessionsCount: stats.sessions,
                hoursRead: stats.duration / 3600
            )
        }
    }

    // MARK: - Year in Review

    func getYearInReviewData(context: NSManagedObjectContext? = nil) -> YearInReviewData {
        let context = context ?? self.context
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())

        // --- sessions for this year ---
        let sessionRequest = NSFetchRequest<NSDictionary>(entityName: "ReadingSession")
        sessionRequest.resultType = .dictionaryResultType
        sessionRequest.propertiesToFetch = [
            "pagesRead", "startDate", "endDate",
            "history.sourceId", "history.mangaId"
        ]

        let yearStart = calendar.date(from: DateComponents(year: currentYear, month: 1, day: 1))!
        let yearEnd = calendar.date(from: DateComponents(year: currentYear + 1, month: 1, day: 1))!
        sessionRequest.predicate = NSPredicate(
            format: "endDate >= %@ AND endDate < %@",
            yearStart as NSDate, yearEnd as NSDate
        )

        let sessions = (try? context.fetch(sessionRequest)) ?? []

        var totalPages = 0
        var totalDuration: Double = 0
        var sessionsCount = 0
        var mangaPages: [MangaIdentifier: Int] = [:]
        var sourcePages: [String: Int] = [:]
        var monthSessions: [Int: Int] = [:]

        for dict in sessions {
            guard let pages = dict["pagesRead"] as? Int,
                  let start = dict["startDate"] as? Date,
                  let end = dict["endDate"] as? Date,
                  let sourceId = dict["history.sourceId"] as? String,
                  let mangaId = dict["history.mangaId"] as? String
            else { continue }

            sessionsCount += 1
            totalPages += pages
            totalDuration += end.timeIntervalSince(start)

            let key = MangaIdentifier(sourceKey: sourceId, mangaKey: mangaId)
            mangaPages[key, default: 0] += pages
            sourcePages[sourceId, default: 0] += pages

            let month = calendar.component(.month, from: end)
            monthSessions[month, default: 0] += 1
        }

        // --- completed chapters this year ---
        let historyRequest = NSFetchRequest<NSDictionary>(entityName: "History")
        historyRequest.resultType = .dictionaryResultType
        historyRequest.predicate = NSPredicate(
            format: "completed == true AND dateRead >= %@ AND dateRead < %@",
            yearStart as NSDate, yearEnd as NSDate
        )
        historyRequest.propertiesToFetch = ["sourceId", "mangaId"]

        let completedHistory = (try? context.fetch(historyRequest)) ?? []

        var chaptersRead = 0
        var mangaWithChapters = Set<MangaIdentifier>()

        for dict in completedHistory {
            chaptersRead += 1
            if let sourceId = dict["sourceId"] as? String,
               let mangaId = dict["mangaId"] as? String {
                mangaWithChapters.insert(.init(sourceKey: sourceId, mangaKey: mangaId))
            }
        }

        // --- top manga ---
        let topMangaEntry = mangaPages.max(by: { $0.value < $1.value })
        var topMangaTitle: String?
        var topMangaCoverUrl: String?
        var topMangaPages = 0
        if let entry = topMangaEntry {
            let manga = self.getManga(sourceId: entry.key.sourceKey, mangaId: entry.key.mangaKey, context: context)
            topMangaTitle = manga?.title ?? entry.key.mangaKey
            topMangaCoverUrl = manga?.cover
            topMangaPages = entry.value
        }

        // --- top source ---
        let topSourceEntry = sourcePages.max(by: { $0.value < $1.value })
        var topSourceName: String?
        var topSourceChapters = 0
        if let entry = topSourceEntry {
            topSourceName = SourceManager.shared.source(for: entry.key)?.name ?? entry.key
            topSourceChapters = entry.value
        }

        // --- top month ---
        let topMonthEntry = monthSessions.max(by: { $0.value < $1.value })
        var topMonthName = ""
        var topMonthCount = 0
        if let entry = topMonthEntry {
            let formatter = DateFormatter()
            formatter.locale = Locale.current
            let symbols = formatter.monthSymbols ?? []
            if entry.key >= 1 && entry.key <= symbols.count {
                topMonthName = symbols[entry.key - 1]
            }
            topMonthCount = entry.value
        }

        return YearInReviewData(
            year: currentYear,
            mangaRead: mangaWithChapters.count,
            chaptersRead: chaptersRead,
            sessionsCount: sessionsCount,
            pagesRead: totalPages,
            hoursRead: Int(totalDuration / 3600),
            topMangaTitle: topMangaTitle,
            topMangaCoverUrl: topMangaCoverUrl,
            topMangaPages: topMangaPages,
            topSourceName: topSourceName,
            topSourceChapters: topSourceChapters,
            topMonthName: topMonthName,
            topMonthChapters: topMonthCount
        )
    }

    // get the number of history items with at least one reading session per day for the last year
    func getReadingHeatmapData(context: NSManagedObjectContext? = nil) -> HeatmapData {
        let context = context ?? self.context

        let calendar = Calendar.current
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date.now))!
        let (totalDays, startDate) = HeatmapData.getDaysAndStartDate()

        let fetchRequest = NSFetchRequest<NSDictionary>(entityName: "ReadingSession")
        fetchRequest.resultType = .dictionaryResultType
        fetchRequest.predicate = NSPredicate(format: "endDate >= %@ AND endDate <= %@", startDate as NSDate, startOfTomorrow as NSDate)
        fetchRequest.propertiesToFetch = [
            "endDate",
            "history.sourceId",
            "history.mangaId",
            "history.chapterId"
        ]
        guard let results = try? context.fetch(fetchRequest) else {
            return .empty()
        }

        var dayToHistorySet: [Date: Set<ChapterIdentifier>] = [:]
        for dict in results {
            guard
                let endDate = dict["endDate"] as? Date,
                let sourceId = dict["history.sourceId"] as? String,
                let mangaId = dict["history.mangaId"] as? String,
                let chapterId = dict["history.chapterId"] as? String
            else { continue }

            let day = calendar.startOfDay(for: endDate)
            dayToHistorySet[day, default: []].insert(.init(sourceKey: sourceId, mangaKey: mangaId, chapterKey: chapterId))
        }

        return .init(
            startDate: startDate,
            values: (0..<totalDays).map { offset in
                let date = calendar.date(byAdding: .day, value: offset, to: startDate)!
                return dayToHistorySet[date]?.count ?? 0
            }
        )
    }
}
