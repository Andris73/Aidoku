//
//  CrossSourceChecker.swift
//  Aidoku
//
//  Cross-source chapter comparison manager.
//  Checks whether other installed sources have newer chapters
//  for manga in the user's library, similar to Kenmei's cross-site tracking.
//

import AidokuRunner
import CoreData
import Foundation

actor CrossSourceChecker {
    static let shared = CrossSourceChecker()

    // MARK: - Types

    struct CrossSourceResult: Sendable {
        let hasNewerSource: Bool
        let newerSourceName: String?
        let newerChapterNumber: Float?
        let currentChapterNumber: Float?
        let checkedAt: Date
    }

    private struct CacheEntry {
        let result: CrossSourceResult
        let timestamp: Date
    }

    // MARK: - Properties

    private var cache: [String: CacheEntry] = [:]
    private let cacheTTL: TimeInterval = 6 * 3600 // 6 hours
    private let searchDelayNanoseconds: UInt64 = 500_000_000 // 0.5s between source searches

    private var isRunning = false

    // MARK: - Public API

    /// Check all library manga for newer sources in the background.
    /// Results are delivered incrementally via the returned async stream.
    func checkLibrary(manga: [MangaInfo]) -> AsyncStream<(MangaIdentifier, CrossSourceResult)> {
        AsyncStream { continuation in
            Task {
                await self.performLibraryCheck(manga: manga, continuation: continuation)
                continuation.finish()
            }
        }
    }

    /// Check a single manga for newer chapters on other sources.
    func check(manga: MangaInfo) async -> CrossSourceResult {
        let key = cacheKey(for: manga)

        if let cached = cache[key], !isCacheExpired(cached) {
            return cached.result
        }

        let result = await performCheck(manga: manga)
        cache[key] = CacheEntry(result: result, timestamp: Date())
        return result
    }

    /// Get a cached result without triggering a new check.
    func cachedResult(for manga: MangaInfo) -> CrossSourceResult? {
        let key = cacheKey(for: manga)
        guard let cached = cache[key], !isCacheExpired(cached) else { return nil }
        return cached.result
    }

    /// Clear the entire cache, forcing fresh checks.
    func clearCache() {
        cache.removeAll()
    }

    /// Evict a single manga from the cache.
    func evict(manga: MangaInfo) {
        cache.removeValue(forKey: cacheKey(for: manga))
    }

    // MARK: - Library Check

    private func performLibraryCheck(
        manga: [MangaInfo],
        continuation: AsyncStream<(MangaIdentifier, CrossSourceResult)>.Continuation
    ) async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }

        let otherSources = await installedSourcesExcludingLocal()
        guard !otherSources.isEmpty else { return }

        for item in manga {
            guard !Task.isCancelled else { break }

            let key = cacheKey(for: item)
            if let cached = cache[key], !isCacheExpired(cached) {
                if cached.result.hasNewerSource {
                    continuation.yield((item.identifier, cached.result))
                }
                continue
            }

            let result = await performCheck(manga: item, availableSources: otherSources)
            cache[key] = CacheEntry(result: result, timestamp: Date())

            if result.hasNewerSource {
                continuation.yield((item.identifier, result))
            }

            // Throttle to avoid hammering sources
            try? await Task.sleep(nanoseconds: searchDelayNanoseconds)
        }
    }

    // MARK: - Single Manga Check

    private func performCheck(
        manga: MangaInfo,
        availableSources: [AidokuRunner.Source]? = nil
    ) async -> CrossSourceResult {
        let noResult = CrossSourceResult(
            hasNewerSource: false,
            newerSourceName: nil,
            newerChapterNumber: nil,
            currentChapterNumber: nil,
            checkedAt: Date()
        )

        guard let title = manga.title, !title.isEmpty else { return noResult }

        let currentMax = await maxChapterNumber(sourceId: manga.sourceId, mangaId: manga.mangaId)
        guard let currentMax else { return noResult }

        let sources = availableSources ?? (await installedSourcesExcludingLocal())
        let otherSources = sources.filter { $0.id != manga.sourceId }
        guard !otherSources.isEmpty else { return noResult }

        // Search each source for a title match and compare chapters
        for source in otherSources {
            guard !Task.isCancelled else { break }

            if let newerChapter = await findNewerChapter(
                in: source,
                title: title,
                currentMax: currentMax
            ) {
                return CrossSourceResult(
                    hasNewerSource: true,
                    newerSourceName: source.name,
                    newerChapterNumber: newerChapter,
                    currentChapterNumber: currentMax,
                    checkedAt: Date()
                )
            }
        }

        return CrossSourceResult(
            hasNewerSource: false,
            newerSourceName: nil,
            newerChapterNumber: nil,
            currentChapterNumber: currentMax,
            checkedAt: Date()
        )
    }

    /// Search a single source for the manga by title and compare chapter numbers.
    private func findNewerChapter(
        in source: AidokuRunner.Source,
        title: String,
        currentMax: Float
    ) async -> Float? {
        guard let matchedManga = await searchForBestMatch(source: source, title: title) else {
            return nil
        }
        guard let remoteMax = await fetchMaxChapter(source: source, manga: matchedManga) else {
            return nil
        }
        return remoteMax > currentMax ? remoteMax : nil
    }

    // MARK: - Source Search

    private func searchForBestMatch(
        source: AidokuRunner.Source,
        title: String
    ) async -> AidokuRunner.Manga? {
        let result = try? await source.getSearchMangaList(query: title, page: 1, filters: [])
        guard let entries = result?.entries, !entries.isEmpty else { return nil }

        // Find best title match from first page results
        let normalizedTitle = title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let exactMatch = entries.first { $0.title.lowercased() == normalizedTitle }
        return exactMatch ?? entries.first
    }

    private func fetchMaxChapter(
        source: AidokuRunner.Source,
        manga: AidokuRunner.Manga
    ) async -> Float? {
        guard
            let updated = try? await source.getMangaUpdate(
                manga: manga,
                needsDetails: false,
                needsChapters: true
            ),
            let chapters = updated.chapters,
            !chapters.isEmpty
        else {
            return nil
        }

        return chapters
            .compactMap { $0.chapterNumber }
            .max()
    }

    // MARK: - Local Chapter Data

    private func maxChapterNumber(sourceId: String, mangaId: String) async -> Float? {
        await CoreDataManager.shared.container.performBackgroundTask { context in
            let chapters = CoreDataManager.shared.getChapters(
                sourceId: sourceId,
                mangaId: mangaId,
                context: context
            )
            return chapters
                .compactMap { $0.chapter?.floatValue }
                .filter { $0 >= 0 }
                .max()
        }
    }

    // MARK: - Helpers

    private func installedSourcesExcludingLocal() async -> [AidokuRunner.Source] {
        await SourceManager.shared.loadSources()
        return SourceManager.shared.sources.filter { $0.id != LocalSourceRunner.sourceKey }
    }

    private func cacheKey(for manga: MangaInfo) -> String {
        "\(manga.sourceId).\(manga.mangaId)"
    }

    private func isCacheExpired(_ entry: CacheEntry) -> Bool {
        Date().timeIntervalSince(entry.timestamp) >= cacheTTL
    }
}