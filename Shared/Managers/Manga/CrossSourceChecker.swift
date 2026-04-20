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

    struct CrossSourceResult: Sendable, Codable {
        let hasNewerSource: Bool
        let newerSourceName: String?
        let newerChapterNumber: Float?
        let currentChapterNumber: Float?
        let checkedAt: Date
    }

    private struct CacheEntry: Codable {
        let result: CrossSourceResult
        let timestamp: Date
    }

    // MARK: - Properties

    private var cache: [String: CacheEntry]
    private let cacheTTL: TimeInterval = 6 * 3600 // 6 hours
    private let searchDelayNanoseconds: UInt64 = 500_000_000 // 0.5s between source searches

    /// Minimum similarity score (0–1) for a title to be considered a match.
    private let minimumSimilarity: Double = 0.75

    // MARK: - Init

    private init() {
        self.cache = Self.loadFromDisk()
    }

    // MARK: - Public API

    /// Check all library manga for newer sources in the background.
    /// Results are delivered incrementally via the returned async stream.
    /// **Every** manga yields a result (not just newer-source hits) so that
    /// consumers can track progress (completed / total).
    func checkLibrary(manga: [MangaInfo]) -> AsyncStream<(MangaIdentifier, CrossSourceResult)> {
        AsyncStream { continuation in
            let producerTask = Task {
                await self.performLibraryCheck(manga: manga, continuation: continuation)
                continuation.finish()
            }
            continuation.onTermination = { _ in
                producerTask.cancel()
            }
        }
    }

    /// Check a single manga for newer chapters on other sources.
    func check(manga: MangaInfo) async -> CrossSourceResult {
        let noResult = CrossSourceResult(
            hasNewerSource: false,
            newerSourceName: nil,
            newerChapterNumber: nil,
            currentChapterNumber: nil,
            checkedAt: Date()
        )

        // Skip if the manga's own source is blacklisted
        guard !excludedSourceIds().contains(manga.sourceId) else { return noResult }

        let key = cacheKey(for: manga)

        if let cached = cache[key], !isCacheExpired(cached) {
            return cached.result
        }

        let result = await performCheck(manga: manga)
        cache[key] = CacheEntry(result: result, timestamp: Date())
        persistCache()
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
        persistCache()
    }

    /// Evict a single manga from the cache.
    func evict(manga: MangaInfo) {
        cache.removeValue(forKey: cacheKey(for: manga))
        persistCache()
    }

    // MARK: - Library Check

    private func performLibraryCheck(
        manga: [MangaInfo],
        continuation: AsyncStream<(MangaIdentifier, CrossSourceResult)>.Continuation
    ) async {
        let excluded = excludedSourceIds()
        let otherSources = await installedSourcesExcludingLocal(excluded: excluded)
        guard !otherSources.isEmpty else { return }

        let noResult = CrossSourceResult(
            hasNewerSource: false,
            newerSourceName: nil,
            newerChapterNumber: nil,
            currentChapterNumber: nil,
            checkedAt: Date()
        )

        for item in manga {
            guard !Task.isCancelled else { break }

            // Skip manga whose own source is blacklisted
            if excluded.contains(item.sourceId) {
                continuation.yield((item.identifier, noResult))
                continue
            }

            let key = cacheKey(for: item)
            if let cached = cache[key], !isCacheExpired(cached) {
                continuation.yield((item.identifier, cached.result))
                continue
            }

            let result = await performCheck(manga: item, availableSources: otherSources)
            cache[key] = CacheEntry(result: result, timestamp: Date())

            guard !Task.isCancelled else { break }
            continuation.yield((item.identifier, result))

            // Throttle to avoid hammering sources
            try? await Task.sleep(nanoseconds: searchDelayNanoseconds)
        }

        // Persist the full batch once the library check completes (or is cancelled)
        persistCache()
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

        let sources: [AidokuRunner.Source]
        if let availableSources {
            sources = availableSources
        } else {
            sources = await installedSourcesExcludingLocal()
        }
        let otherSources = sources.filter { $0.id != manga.sourceId }
        guard !otherSources.isEmpty else { return noResult }

        // Search each source for a verified title match and compare chapters
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

    // MARK: - Source Search (Robust Matching)

    /// Searches a source for the given title and returns the best-matching manga
    /// only if it passes a strict similarity threshold. Returns `nil` for poor matches.
    private func searchForBestMatch(
        source: AidokuRunner.Source,
        title: String
    ) async -> AidokuRunner.Manga? {
        let result = try? await source.getSearchMangaList(query: title, page: 1, filters: [])
        guard let entries = result?.entries, !entries.isEmpty else { return nil }

        let normalizedQuery = Self.normalize(title)
        guard !normalizedQuery.isEmpty else { return nil }

        var bestMatch: AidokuRunner.Manga?
        var bestScore: Double = 0

        for entry in entries {
            let normalizedCandidate = Self.normalize(entry.title)
            guard !normalizedCandidate.isEmpty else { continue }

            let score = Self.titleSimilarity(normalizedQuery, normalizedCandidate)
            if score > bestScore {
                bestScore = score
                bestMatch = entry
            }
            // Perfect match — stop early
            if score >= 1.0 { break }
        }

        guard bestScore >= minimumSimilarity else { return nil }
        return bestMatch
    }

    // MARK: - Title Normalization & Similarity

    /// Normalizes a manga title for comparison:
    /// lowercased, stripped of non-alphanumeric characters (except spaces),
    /// collapsed whitespace, trimmed.
    private static func normalize(_ title: String) -> String {
        let lowered = title.lowercased()
        let stripped = lowered.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) || scalar == " "
                ? Character(scalar)
                : Character(" ")
        }
        return String(stripped)
            .split(separator: " ")
            .joined(separator: " ")
    }

    /// Computes an overall similarity score (0–1) between two **already-normalized** titles
    /// by combining exact match, containment, word overlap (Jaccard), and
    /// bigram similarity (Sørensen–Dice).
    private static func titleSimilarity(_ a: String, _ b: String) -> Double {
        // 1. Exact match
        if a == b { return 1.0 }

        // 2. Containment — one title is a substring of the other.
        //    Only accept if the shorter string is at least 70 % of the longer.
        let containmentScore = containmentSimilarity(a, b)
        if containmentScore >= 0.90 { return containmentScore }

        // 3. Word-level Jaccard index
        let wordScore = wordJaccard(a, b)

        // 4. Character-bigram Sørensen–Dice coefficient
        let bigramScore = bigramDice(a, b)

        // Take the higher of the two fuzzy scores
        return max(wordScore, max(bigramScore, containmentScore))
    }

    /// Returns a containment-based score if one string contains the other, else 0.
    private static func containmentSimilarity(_ a: String, _ b: String) -> Double {
        let shorter = a.count <= b.count ? a : b
        let longer = a.count > b.count ? a : b
        guard longer.contains(shorter) else { return 0 }
        return Double(shorter.count) / Double(longer.count)
    }

    /// Jaccard index over word sets.
    private static func wordJaccard(_ a: String, _ b: String) -> Double {
        let setA = Set(a.split(separator: " ").map(String.init))
        let setB = Set(b.split(separator: " ").map(String.init))
        let union = setA.union(setB)
        guard !union.isEmpty else { return 0 }
        return Double(setA.intersection(setB).count) / Double(union.count)
    }

    /// Sørensen–Dice coefficient over character bigrams.
    private static func bigramDice(_ a: String, _ b: String) -> Double {
        let bigramsA = bigrams(of: a)
        let bigramsB = bigrams(of: b)
        let totalCount = bigramsA.count + bigramsB.count
        guard totalCount > 0 else { return 0 }

        // Count shared bigrams (multiset intersection)
        var bagB = [String: Int]()
        for bg in bigramsB { bagB[bg, default: 0] += 1 }

        var shared = 0
        for bg in bigramsA {
            if let remaining = bagB[bg], remaining > 0 {
                shared += 1
                bagB[bg] = remaining - 1
            }
        }
        return (2.0 * Double(shared)) / Double(totalCount)
    }

    /// Extracts character bigrams from a string (ignoring spaces).
    private static func bigrams(of string: String) -> [String] {
        let chars = Array(string.filter { $0 != " " })
        guard chars.count >= 2 else { return [] }
        return (0..<chars.count - 1).map { String(chars[$0]) + String(chars[$0 + 1]) }
    }

    // MARK: - Remote Chapter Fetch

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

    /// Returns the set of source IDs the user has excluded from cross-source checking.
    private nonisolated func excludedSourceIds() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: "Library.crossSourceExcludedSources") ?? [])
    }

    private func installedSourcesExcludingLocal(excluded: Set<String>? = nil) async -> [AidokuRunner.Source] {
        let excluded = excluded ?? excludedSourceIds()
        await SourceManager.shared.reloadSources()
        return SourceManager.shared.sources.filter {
            $0.id != LocalSourceRunner.sourceKey && !excluded.contains($0.id)
        }
    }

    private func cacheKey(for manga: MangaInfo) -> String {
        "\(manga.sourceId).\(manga.mangaId)"
    }

    private func isCacheExpired(_ entry: CacheEntry) -> Bool {
        Date().timeIntervalSince(entry.timestamp) >= cacheTTL
    }

    // MARK: - Persistence

    private static var cacheFileURL: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return caches.appendingPathComponent("AidokuCrossSourceCache.json")
    }

    /// Loads the persisted cache from disk, discarding any entries that have already expired.
    private static func loadFromDisk() -> [String: CacheEntry] {
        guard
            let data = try? Data(contentsOf: cacheFileURL),
            let decoded = try? JSONDecoder().decode([String: CacheEntry].self, from: data)
        else { return [:] }

        let ttl: TimeInterval = 6 * 3600
        let now = Date()
        return decoded.filter { now.timeIntervalSince($0.value.timestamp) < ttl }
    }

    /// Writes the current in-memory cache to disk, omitting expired entries.
    private func persistCache() {
        let validEntries = cache.filter { !isCacheExpired($0.value) }
        guard let data = try? JSONEncoder().encode(validEntries) else { return }
        try? data.write(to: Self.cacheFileURL, options: .atomic)
    }
}
