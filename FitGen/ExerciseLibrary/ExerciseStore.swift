import Foundation
import Combine

// MARK: - ExerciseStore
//
// Single source of truth for the exercise catalog.
//
// Caching strategy
// ----------------
//  • The full ExerciseDB catalog (~1300 items) is small enough to hold in
//    memory and persist as one JSON file in the Caches directory.
//  • First launch: paginate the API, persist to disk, publish incrementally.
//  • Subsequent launches: load disk cache instantly (works fully offline),
//    then refresh in the background only if the cache is older than `ttl`.
//  • All search / filtering is done locally against the in-memory list, so
//    after the initial sync there are zero API calls for browsing.
//  • GIF binaries are cached separately on disk by SDWebImage.

@MainActor
final class ExerciseStore: ObservableObject {

    static let shared = ExerciseStore()

    @Published private(set) var exercises: [LibraryExercise] = []
    @Published private(set) var bodyParts: [String] = []
    @Published private(set) var equipmentTypes: [String] = []
    @Published private(set) var isSyncing = false
    @Published private(set) var lastError: String?

    /// True while we have no data at all (used to drive the empty/loading UI).
    var isEmpty: Bool { exercises.isEmpty }

    /// Refresh the catalog at most once per week.
    private let ttl: TimeInterval = 60 * 60 * 24 * 7

    private let fileName = "exercise_catalog.json"
    private var didLoadFromDisk = false

    private init() {}

    // MARK: Lifecycle

    /// Call once when the library UI appears. Loads cache, then refreshes if stale.
    func bootstrap() async {
        if !didLoadFromDisk {
            loadFromDisk()
            didLoadFromDisk = true
        }
        if shouldRefresh {
            await sync()
        } else if bodyParts.isEmpty {
            await refreshFilterLists()
        }
    }

    /// Force a full re-sync (pull-to-refresh / retry button).
    func refresh() async {
        await sync()
    }

    // MARK: Sync

    private var shouldRefresh: Bool {
        guard let date = cacheDate else { return true }      // never synced
        return Date().timeIntervalSince(date) > ttl          // stale
    }

    private func sync() async {
        guard !isSyncing else { return }
        isSyncing = true
        lastError = nil
        defer { isSyncing = false }

        var all: [LibraryExercise] = []
        var offset = 0
        let maxOffset = 4000   // safety stop (~1300 real exercises today)

        do {
            // The API caps pages at 10 items and rate-limits bursts, so step by
            // the returned count and throttle gently between requests.
            while offset < maxOffset {
                let page = try await ExerciseDBService.fetchPage(offset: offset)
                if page.isEmpty { break }
                all.append(contentsOf: page)
                self.exercises = dedupe(all)          // progressive publish
                offset += page.count
                try? await Task.sleep(nanoseconds: 150_000_000)
            }
            persistIfNonEmpty(all)
            await refreshFilterLists()
        } catch {
            // Offline / rate-limited: keep + persist whatever we managed to load.
            persistIfNonEmpty(all)
            lastError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            if exercises.isEmpty { deriveFilterListsLocally() }
        }
    }

    private func persistIfNonEmpty(_ list: [LibraryExercise]) {
        let deduped = dedupe(list)
        guard !deduped.isEmpty else { return }
        self.exercises = deduped
        persist(deduped)
    }

    private func refreshFilterLists() async {
        // Prefer the canonical server lists; fall back to deriving from data.
        async let parts = try? ExerciseDBService.bodyPartList()
        async let gear  = try? ExerciseDBService.equipmentList()
        let (p, g) = await (parts, gear)

        if let p, !p.isEmpty { bodyParts = p.sorted() } else { deriveBodyParts() }
        if let g, !g.isEmpty { equipmentTypes = g.sorted() } else { deriveEquipment() }
    }

    private func deriveFilterListsLocally() {
        deriveBodyParts()
        deriveEquipment()
    }

    private func deriveBodyParts() {
        bodyParts = Set(exercises.map(\.bodyPart)).filter { !$0.isEmpty }.sorted()
    }

    private func deriveEquipment() {
        equipmentTypes = Set(exercises.map(\.equipment)).filter { !$0.isEmpty }.sorted()
    }

    private func dedupe(_ list: [LibraryExercise]) -> [LibraryExercise] {
        var seen = Set<String>()
        return list.filter { seen.insert($0.id).inserted }
    }

    // MARK: Name lookup (attach a GIF + info to AI-program exercises)

    private var matchCache: [String: LibraryExercise] = [:]
    private var didLoadMatchCache = false

    /// Resolves a free-text exercise name (from the AI program) to a catalog
    /// entry. Order: persistent cache → local catalog (token match) →
    /// on-demand ExerciseDB name search. Successful matches are cached to disk
    /// so they resolve instantly and work offline afterwards.
    func resolveMatch(forName query: String) async -> LibraryExercise? {
        let key = Self.normalizedKey(query)
        guard !key.isEmpty else { return nil }

        loadMatchCacheIfNeeded()
        if let cached = matchCache[key] { return cached }

        // Load the on-disk catalog (without triggering a network sync).
        if !didLoadFromDisk { loadFromDisk(); didLoadFromDisk = true }

        if let local = bestMatch(forName: query) {
            cacheMatch(local, for: key)
            return local
        }

        let qTokens = Set(Self.tokens(query))
        for term in Self.searchTerms(forName: query) {
            guard let results = try? await ExerciseDBService.search(name: term),
                  !results.isEmpty else { continue }
            if let best = Self.rank(results, queryTokens: qTokens) {
                cacheMatch(best, for: key)
                return best
            }
        }
        return nil
    }

    /// Best token-overlap match within the already-loaded catalog.
    func bestMatch(forName query: String) -> LibraryExercise? {
        guard !exercises.isEmpty else { return nil }
        let qTokens = Set(Self.tokens(query))
        return Self.rank(exercises, queryTokens: qTokens)
    }

    // MARK: Matching internals

    /// Ranks candidates by how many query word-stems they share, requiring at
    /// least half the query words to match and preferring tighter (shorter) names.
    private static func rank(_ list: [LibraryExercise], queryTokens qs: Set<String>) -> LibraryExercise? {
        guard !qs.isEmpty else { return nil }
        var best: LibraryExercise?
        var bestScore = 0.0
        for ex in list {
            let ns = Set(tokens(ex.name))
            let shared = qs.intersection(ns)
            if shared.isEmpty || ns.isEmpty { continue }
            let coverage = Double(shared.count) / Double(qs.count)
            if coverage < 0.5 { continue }
            let precision = Double(shared.count) / Double(ns.count)
            let score = coverage * 0.75 + precision * 0.25
            if score > bestScore {
                bestScore = score
                best = ex
            }
        }
        return best
    }

    /// Lowercased, punctuation-free words (no stemming) — used for the API's
    /// literal substring search so terms stay matchable.
    private static func rawTokens(_ s: String) -> [String] {
        s.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    /// Word stems (drops a trailing plural "s") — used for fuzzy ranking so
    /// "triceps" matches "tricep", "curls" matches "curl", etc.
    private static func tokens(_ s: String) -> [String] {
        rawTokens(s).map { ($0.count > 3 && $0.hasSuffix("s")) ? String($0.dropLast()) : $0 }
    }

    private static func normalizedKey(_ s: String) -> String {
        tokens(s).joined(separator: " ")
    }

    /// Search terms to try against the API, broad → broader: full phrase, then
    /// the last two words (usually the movement), then the last word.
    private static func searchTerms(forName query: String) -> [String] {
        let t = rawTokens(query)
        var terms: [String] = []
        if !t.isEmpty { terms.append(t.joined(separator: " ")) }
        if t.count >= 2 { terms.append(t.suffix(2).joined(separator: " ")) }
        if let last = t.last { terms.append(last) }
        var seen = Set<String>()
        return terms.filter { seen.insert($0).inserted }
    }

    // MARK: Match-cache persistence

    private var matchCacheURL: URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("exercise_match_cache.json")
    }

    private func loadMatchCacheIfNeeded() {
        guard !didLoadMatchCache else { return }
        didLoadMatchCache = true
        guard let data = try? Data(contentsOf: matchCacheURL),
              let decoded = try? JSONDecoder().decode([String: LibraryExercise].self, from: data)
        else { return }
        matchCache = decoded
    }

    private func cacheMatch(_ ex: LibraryExercise, for key: String) {
        matchCache[key] = ex
        if let data = try? JSONEncoder().encode(matchCache) {
            try? data.write(to: matchCacheURL, options: .atomic)
        }
    }

    // MARK: Disk persistence

    private var cacheURL: URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent(fileName)
    }

    private var cacheDate: Date? {
        try? FileManager.default.attributesOfItem(atPath: cacheURL.path)[.modificationDate] as? Date
    }

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: cacheURL) else { return }
        guard let decoded = try? JSONDecoder().decode([LibraryExercise].self, from: data) else { return }
        exercises = decoded
        deriveFilterListsLocally()
    }

    private func persist(_ list: [LibraryExercise]) {
        guard let data = try? JSONEncoder().encode(list) else { return }
        try? data.write(to: cacheURL, options: .atomic)
    }
}
