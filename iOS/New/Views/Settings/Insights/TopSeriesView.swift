//
//  TopSeriesView.swift
//  Aidoku
//
//  Created on 2025-01-01.
//

import SwiftUI

struct TopSeriesView: View {
    let series: [TopSeriesEntry]

    var body: some View {
        if !series.isEmpty {
            VStack(alignment: .leading, spacing: 5) {
                Text(NSLocalizedString("TOP_SERIES"))
                    .font(.system(size: 15).weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)

                InsightPlatterView {
                    VStack(spacing: 0) {
                        ForEach(Array(series.enumerated()), id: \.element.id) { index, entry in
                            if index > 0 {
                                Divider()
                                    .padding(.leading, 56)
                            }
                            TopSeriesRow(rank: index + 1, entry: entry)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
    }
}

// MARK: - Row

private struct TopSeriesRow: View {
    let rank: Int
    let entry: TopSeriesEntry

    var body: some View {
        HStack(spacing: 12) {
            rankBadge
            coverImage
            titleAndStats
            Spacer(minLength: 0)
            pageCount
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private var rankBadge: some View {
        Text("#\(rank)")
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(rankColor)
            .frame(width: 28, alignment: .center)
    }

    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .secondary
        }
    }

    private var coverImage: some View {
        Group {
            if let urlString = entry.coverUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        placeholderImage
                    default:
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            } else {
                placeholderImage
            }
        }
        .frame(width: 36, height: 50)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
        )
    }

    private var placeholderImage: some View {
        ZStack {
            Color(uiColor: .tertiarySystemGroupedBackground)
            Image(systemName: "book.closed.fill")
                .font(.system(size: 14))
                .foregroundStyle(.quaternary)
        }
    }

    private var titleAndStats: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(entry.title)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(2)

            HStack(spacing: 8) {
                statLabel(
                    icon: "clock",
                    text: formattedHours
                )
                statLabel(
                    icon: "book.pages",
                    text: String(
                        format: NSLocalizedString("X_SESSIONS_%d", comment: ""),
                        entry.sessionsCount
                    )
                )
            }
        }
    }

    private func statLabel(icon: String, text: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(text)
                .font(.system(size: 11))
        }
        .foregroundStyle(.secondary)
    }

    private var pageCount: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(entry.pagesRead, format: .number.notation(.compactName))
                .font(.system(size: 18, weight: .bold, design: .rounded))
            Text(entry.pagesRead == 1
                 ? NSLocalizedString("PAGE_SINGULAR")
                 : NSLocalizedString("PAGE_PLURAL"))
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }

    private var formattedHours: String {
        let hours = entry.hoursRead
        if hours < 1 {
            let minutes = Int(hours * 60)
            return "\(max(minutes, 1))m"
        } else if hours < 10 {
            return String(format: "%.1fh", hours)
        } else {
            return "\(Int(hours))h"
        }
    }
}

#Preview {
    ScrollView {
        TopSeriesView(series: [
            .init(
                sourceId: "src1", mangaId: "m1",
                title: "One Piece",
                coverUrl: nil,
                pagesRead: 1200,
                sessionsCount: 45,
                hoursRead: 12.5
            ),
            .init(
                sourceId: "src1", mangaId: "m2",
                title: "Chainsaw Man",
                coverUrl: nil,
                pagesRead: 840,
                sessionsCount: 32,
                hoursRead: 8.2
            ),
            .init(
                sourceId: "src1", mangaId: "m3",
                title: "Jujutsu Kaisen",
                coverUrl: nil,
                pagesRead: 620,
                sessionsCount: 24,
                hoursRead: 5.7
            ),
            .init(
                sourceId: "src2", mangaId: "m4",
                title: "Dandadan",
                coverUrl: nil,
                pagesRead: 410,
                sessionsCount: 18,
                hoursRead: 3.4
            ),
            .init(
                sourceId: "src2", mangaId: "m5",
                title: "Spy x Family",
                coverUrl: nil,
                pagesRead: 280,
                sessionsCount: 12,
                hoursRead: 2.1
            )
        ])
        .padding()
    }
    .background(Color(uiColor: .systemGroupedBackground))
}
