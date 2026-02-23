//
//  InsightHighlightsView.swift
//  Aidoku
//
//  Created on 2025-01-01.
//

import SwiftUI

struct InsightHighlightsView: View {
    let chaptersTotal: Int
    let chaptersMonth: Int
    let chaptersYear: Int
    let chaptersPreviousMonth: Int
    let avgSessionMinutes: Int

    private var chaptersTrend: Double? {
        guard chaptersPreviousMonth > 0 else { return nil }
        return Double(chaptersMonth - chaptersPreviousMonth) / Double(chaptersPreviousMonth) * 100
    }

    var body: some View {
        HStack(spacing: 8) {
            chaptersPlatter
            avgSessionPlatter
        }
    }

    // MARK: - Chapters Read

    private var chaptersPlatter: some View {
        InsightPlatterView {
            VStack(spacing: 4) {
                Text(chaptersTotal, format: .number.notation(.compactName))
                    .font(.system(size: 34).weight(.bold))

                Text(chaptersTotal == 1
                     ? NSLocalizedString("CHAPTER_SINGULAR")
                     : NSLocalizedString("CHAPTER_PLURAL"))
                    .font(.system(size: 14).weight(.medium))
                    .foregroundStyle(.secondary)

                Divider()
                    .padding(.horizontal, 12)

                HStack(spacing: 12) {
                    monthStat(value: chaptersMonth, label: NSLocalizedString("THIS_MONTH"))
                    yearStat(value: chaptersYear, label: NSLocalizedString("THIS_YEAR"))
                }
                .padding(.bottom, 4)

                trendView
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .frame(height: 170)
        }
    }

    // MARK: - Average Session Duration

    private var avgSessionPlatter: some View {
        InsightPlatterView {
            VStack(spacing: 6) {
                Image(systemName: "timer")
                    .font(.system(size: 22))
                    .foregroundStyle(.secondary)

                Text(formattedDuration)
                    .font(.system(size: 34).weight(.bold))

                Text(NSLocalizedString("AVG_SESSION"))
                    .font(.system(size: 14).weight(.medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .frame(height: 170)
        }
    }

    // MARK: - Helpers

    private var formattedDuration: String {
        if avgSessionMinutes < 1 {
            return "<1m"
        } else if avgSessionMinutes < 60 {
            return "\(avgSessionMinutes)m"
        } else {
            let hours = avgSessionMinutes / 60
            let mins = avgSessionMinutes % 60
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        }
    }

    private func monthStat(value: Int, label: String) -> some View {
        VStack(spacing: 1) {
            Text(value, format: .number.notation(.compactName))
                .font(.system(size: 16).weight(.bold))
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }

    private func yearStat(value: Int, label: String) -> some View {
        VStack(spacing: 1) {
            Text(value, format: .number.notation(.compactName))
                .font(.system(size: 16).weight(.bold))
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var trendView: some View {
        if let trend = chaptersTrend {
            let isPositive = trend >= 0
            let icon = isPositive ? "arrow.up.right" : "arrow.down.right"
            let color: Color = isPositive ? .green : .red
            let text = String(format: "%+.0f%%", trend)

            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .bold))
                Text(text)
                    .font(.system(size: 11, weight: .semibold))
                Text(NSLocalizedString("VS_LAST_MONTH"))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(color)
        }
    }
}

#Preview {
    InsightHighlightsView(
        chaptersTotal: 248,
        chaptersMonth: 12,
        chaptersYear: 180,
        chaptersPreviousMonth: 9,
        avgSessionMinutes: 23
    )
    .padding()
}
