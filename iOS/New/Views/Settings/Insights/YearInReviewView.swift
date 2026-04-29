//
//  YearInReviewView.swift
//  Aidoku
//
//  Created on 2025-01-01.
//

import SwiftUI

struct YearInReviewView: View {
    let data: YearInReviewData

    var body: some View {
        if !data.isEmpty {
            VStack(alignment: .leading, spacing: 5) {
                Text(String(format: NSLocalizedString("YEAR_IN_REVIEW_%d", comment: ""), data.year))
                    .font(.system(size: 15).weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)

                InsightPlatterView {
                    VStack(spacing: 0) {
                        headerSection
                        Divider().padding(.horizontal, 16)
                        statsGrid
                        if hasTopHighlights {
                            Divider().padding(.horizontal, 16)
                            highlightsSection
                        }
                    }
                    .padding(.vertical, 14)
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 4) {
            Text(String(format: "%d", data.year))
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Text(NSLocalizedString("YEAR_IN_REVIEW_SUBTITLE"))
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 14)
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ],
            spacing: 16
        ) {
            statCell(
                value: data.mangaRead,
                label: data.mangaRead == 1
                    ? NSLocalizedString("SERIES_SINGULAR")
                    : NSLocalizedString("SERIES_PLURAL"),
                icon: "books.vertical"
            )
            statCell(
                value: data.chaptersRead,
                label: data.chaptersRead == 1
                    ? NSLocalizedString("CHAPTER_SINGULAR")
                    : NSLocalizedString("CHAPTER_PLURAL"),
                icon: "bookmark"
            )
            statCell(
                value: data.sessionsCount,
                label: data.sessionsCount == 1
                    ? NSLocalizedString("SESSION_SINGULAR")
                    : NSLocalizedString("SESSION_PLURAL"),
                icon: "book.pages"
            )
            statCell(
                value: data.hoursRead,
                label: data.hoursRead == 1
                    ? NSLocalizedString("HOUR_SINGULAR")
                    : NSLocalizedString("HOUR_PLURAL"),
                icon: "clock"
            )
            if !data.topMonthName.isEmpty && data.topMonthChapters > 0 {
                topMonthCell
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func statCell(value: Int, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
            Text(value, format: .number.notation(.compactName))
                .font(.system(size: 22, weight: .bold, design: .rounded))
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    private var topMonthCell: some View {
        VStack(spacing: 4) {
            Image(systemName: "calendar")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
            Text(data.topMonthName)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(NSLocalizedString("TOP_MONTH"))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Highlights

    private var hasTopHighlights: Bool {
        data.topMangaTitle != nil || data.topSourceName != nil
    }

    private var highlightsSection: some View {
        VStack(spacing: 12) {
            if let mangaTitle = data.topMangaTitle {
                highlightRow(
                    icon: "star.fill",
                    iconColor: .yellow,
                    title: NSLocalizedString("TOP_MANGA"),
                    value: mangaTitle,
                    detail: String(
                        format: NSLocalizedString("X_CHAPTERS_%d", comment: ""),
                        data.topMangaChapters
                    )
                )
            }

            if let sourceName = data.topSourceName {
                highlightRow(
                    icon: "globe",
                    iconColor: .blue,
                    title: NSLocalizedString("TOP_SOURCE"),
                    value: sourceName,
                    detail: String(
                        format: NSLocalizedString("X_CHAPTERS_%d", comment: ""),
                        data.topSourceChapters
                    )
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func highlightRow(
        icon: String,
        iconColor: Color,
        title: String,
        value: String,
        detail: String
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(iconColor)
                .frame(width: 28, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Text(value)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            Text(detail)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    ScrollView {
        YearInReviewView(data: .demoData)
            .padding()
    }
    .background(Color(uiColor: .systemGroupedBackground))
}