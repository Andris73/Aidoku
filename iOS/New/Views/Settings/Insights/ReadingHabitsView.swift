//
//  ReadingHabitsView.swift
//  Aidoku
//
//  Created on 2025-01-01.
//

import SwiftUI

struct ReadingHabitsView: View {
    let data: ReadingHabitsData

    var body: some View {
        if !data.isEmpty {
            VStack(alignment: .leading, spacing: 5) {
                Text(NSLocalizedString("READING_HABITS"))
                    .font(.system(size: 15).weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)

                VStack(spacing: 8) {
                    timeOfDaySection
                    dayOfWeekSection
                }
            }
        }
    }

    // MARK: - Time of Day

    private var timeOfDaySection: some View {
        InsightPlatterView {
            VStack(alignment: .leading, spacing: 10) {
                headerRow(
                    title: NSLocalizedString("TIME_OF_DAY"),
                    subtitle: peakTimeSubtitle
                )

                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(TimeOfDayBucket.allCases, id: \.rawValue) { bucket in
                        let value = data.timeOfDay[bucket.rawValue]
                        let maxValue = data.timeOfDay.max() ?? 1
                        let isPeak = value == maxValue && value > 0

                        timeOfDayBar(
                            bucket: bucket,
                            value: value,
                            maxValue: maxValue,
                            isPeak: isPeak
                        )
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func timeOfDayBar(
        bucket: TimeOfDayBucket,
        value: Int,
        maxValue: Int,
        isPeak: Bool
    ) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isPeak ? .primary : .secondary)

            GeometryReader { geo in
                let fraction = maxValue > 0
                    ? CGFloat(value) / CGFloat(maxValue)
                    : 0
                let barHeight = max(fraction * geo.size.height, 2)

                VStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isPeak ? Color.accentColor : Color.accentColor.opacity(0.35))
                        .frame(height: barHeight)
                }
            }
            .frame(height: 60)

            Image(systemName: bucket.icon)
                .font(.system(size: 14))
                .foregroundStyle(isPeak ? .primary : .secondary)

            Text(bucket.label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private var peakTimeSubtitle: String? {
        guard let peak = data.peakTimeOfDay else { return nil }
        return String(format: NSLocalizedString("MOST_ACTIVE_%@", comment: ""), peak.label)
    }

    // MARK: - Day of Week

    private var dayOfWeekSection: some View {
        InsightPlatterView {
            VStack(alignment: .leading, spacing: 10) {
                headerRow(
                    title: NSLocalizedString("DAY_OF_WEEK"),
                    subtitle: peakDaySubtitle
                )

                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(DayOfWeek.allCases, id: \.rawValue) { day in
                        let value = data.dayOfWeek[day.rawValue]
                        let maxValue = data.dayOfWeek.max() ?? 1
                        let isPeak = value == maxValue && value > 0

                        dayOfWeekBar(
                            day: day,
                            value: value,
                            maxValue: maxValue,
                            isPeak: isPeak
                        )
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func dayOfWeekBar(
        day: DayOfWeek,
        value: Int,
        maxValue: Int,
        isPeak: Bool
    ) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isPeak ? .primary : .secondary)

            GeometryReader { geo in
                let fraction = maxValue > 0
                    ? CGFloat(value) / CGFloat(maxValue)
                    : 0
                let barHeight = max(fraction * geo.size.height, 2)

                VStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 3)
                        .fill(isPeak ? Color.accentColor : Color.accentColor.opacity(0.35))
                        .frame(height: barHeight)
                }
            }
            .frame(height: 50)

            Text(day.shortLabel)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isPeak ? .primary : .secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var peakDaySubtitle: String? {
        guard let peak = data.peakDayOfWeek else { return nil }
        return String(format: NSLocalizedString("MOST_ACTIVE_%@", comment: ""), peak.label)
    }

    // MARK: - Shared

    private func headerRow(title: String, subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    ScrollView {
        ReadingHabitsView(data: .demo)
            .padding()
    }
    .background(Color(uiColor: .systemGroupedBackground))
}