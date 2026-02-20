//
//  SmallStatsData.swift
//  Aidoku
//
//  Created by Skitty on 12/20/25.
//

struct SmallStatData {
    var total: Int
    var thisMonth: Int
    var thisYear: Int
    var previousMonth: Int
    var subtitle: String
    var singularSubtitle: String?

    /// Month-over-month percentage change, nil if previous month had no data.
    var monthOverMonthChange: Double? {
        guard previousMonth > 0 else { return nil }
        return Double(thisMonth - previousMonth) / Double(previousMonth) * 100
    }
}