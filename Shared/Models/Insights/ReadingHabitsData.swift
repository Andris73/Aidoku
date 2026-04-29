//
//  ReadingHabitsData.swift
//  Aidoku
//
//  Created on 2025-01-01.
//

import Foundation

struct ReadingHabitsData {
    /// Session counts per time-of-day bucket: [morning, afternoon, evening, night]
    let timeOfDay: [Int]
    /// Session counts per day of week: [Mon, Tue, Wed, Thu, Fri, Sat, Sun]
    let dayOfWeek: [Int]

    var peakTimeOfDay: TimeOfDayBucket? {
        guard let max = timeOfDay.max(), max > 0,
              let index = timeOfDay.firstIndex(of: max)
        else { return nil }
        return TimeOfDayBucket(rawValue: index)
    }

    var peakDayOfWeek: DayOfWeek? {
        guard let max = dayOfWeek.max(), max > 0,
              let index = dayOfWeek.firstIndex(of: max)
        else { return nil }
        return DayOfWeek(rawValue: index)
    }

    var totalSessions: Int {
        timeOfDay.reduce(0, +)
    }

    var isEmpty: Bool {
        totalSessions == 0
    }

    static let empty = ReadingHabitsData(
        timeOfDay: [0, 0, 0, 0],
        dayOfWeek: [0, 0, 0, 0, 0, 0, 0]
    )

    static let demo = ReadingHabitsData(
        timeOfDay: [12, 34, 48, 8],
        dayOfWeek: [8, 14, 10, 18, 22, 35, 28]
    )
}

// MARK: - Time of Day

enum TimeOfDayBucket: Int, CaseIterable {
    case morning = 0    // 6:00–11:59
    case afternoon = 1  // 12:00–17:59
    case evening = 2    // 18:00–21:59
    case night = 3      // 22:00–5:59

    var label: String {
        switch self {
        case .morning:   return NSLocalizedString("TIME_MORNING", comment: "")
        case .afternoon: return NSLocalizedString("TIME_AFTERNOON", comment: "")
        case .evening:   return NSLocalizedString("TIME_EVENING", comment: "")
        case .night:     return NSLocalizedString("TIME_NIGHT", comment: "")
        }
    }

    var icon: String {
        switch self {
        case .morning:   return "sunrise.fill"
        case .afternoon: return "sun.max.fill"
        case .evening:   return "sunset.fill"
        case .night:     return "moon.fill"
        }
    }

    static func bucket(forHour hour: Int) -> TimeOfDayBucket {
        switch hour {
        case 6..<12:  return .morning
        case 12..<18: return .afternoon
        case 18..<22: return .evening
        default:      return .night
        }
    }
}

// MARK: - Day of Week

enum DayOfWeek: Int, CaseIterable {
    case monday = 0
    case tuesday = 1
    case wednesday = 2
    case thursday = 3
    case friday = 4
    case saturday = 5
    case sunday = 6

    var shortLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        let symbols = formatter.shortWeekdaySymbols ?? []
        // shortWeekdaySymbols is Sun=0..Sat=6, map our Mon=0..Sun=6
        let calendarIndex = (rawValue + 1) % 7
        guard calendarIndex < symbols.count else { return "" }
        return symbols[calendarIndex]
    }

    var label: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        let symbols = formatter.weekdaySymbols ?? []
        let calendarIndex = (rawValue + 1) % 7
        guard calendarIndex < symbols.count else { return "" }
        return symbols[calendarIndex]
    }

    /// Convert from `Calendar.component(.weekday)` (1=Sun..7=Sat) to DayOfWeek (0=Mon..6=Sun)
    static func from(calendarWeekday weekday: Int) -> DayOfWeek {
        let adjusted = (weekday + 5) % 7
        return DayOfWeek(rawValue: adjusted) ?? .monday
    }
}