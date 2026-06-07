import Foundation
import Combine

// MARK: - ExerciseLibraryViewModel
//
// Drives ExerciseListScreen. Backed by `ExerciseStore` (which owns the cache
// and networking); this layer only handles search + filtering + paging of the
// already-loaded, locally-cached list, so browsing makes zero API calls.

@MainActor
final class ExerciseLibraryViewModel: ObservableObject {

    // Filters / search
    @Published var searchText = ""
    @Published var selectedBodyPart: String? = nil
    @Published var selectedEquipment: String? = nil

    // Output
    @Published private(set) var visible: [LibraryExercise] = []

    // Lazy rendering: grow the visible window as the user scrolls.
    private let pageSize = 30
    @Published private(set) var window = 30

    private let store: ExerciseStore
    private var bag = Set<AnyCancellable>()

    init(store: ExerciseStore? = nil) {
        let store = store ?? .shared
        self.store = store

        // Recompute whenever the catalog or any filter changes.
        Publishers.CombineLatest4(
            store.$exercises,
            $searchText.removeDuplicates().debounce(for: .milliseconds(200), scheduler: RunLoop.main),
            $selectedBodyPart,
            $selectedEquipment
        )
        .map { [weak self] all, query, part, gear in
            self?.window = self?.pageSize ?? 30      // reset paging on filter change
            return Self.filter(all, query: query, bodyPart: part, equipment: gear)
        }
        .assign(to: &$filtered)

        $filtered
            .combineLatest($window)
            .map { list, window in Array(list.prefix(window)) }
            .assign(to: &$visible)
    }

    // Full filtered result (the visible window is a prefix of this).
    @Published private(set) var filtered: [LibraryExercise] = []

    var totalCount: Int { filtered.count }
    var canLoadMore: Bool { window < filtered.count }
    var isSyncing: Bool { store.isSyncing }
    var isEmpty: Bool { store.isEmpty }
    var syncError: String? { store.lastError }
    var bodyParts: [String] { store.bodyParts }
    var equipmentTypes: [String] { store.equipmentTypes }

    // MARK: Intents

    func onAppear() async { await store.bootstrap() }
    func retry() async { await store.refresh() }

    func loadMoreIfNeeded(current item: LibraryExercise) {
        guard canLoadMore else { return }
        // Trigger when the user nears the end of the current window.
        if let idx = visible.firstIndex(of: item), idx >= visible.count - 6 {
            window = min(window + pageSize, filtered.count)
        }
    }

    func clearFilters() {
        searchText = ""
        selectedBodyPart = nil
        selectedEquipment = nil
    }

    var hasActiveFilters: Bool {
        !searchText.isEmpty || selectedBodyPart != nil || selectedEquipment != nil
    }

    // MARK: Filtering

    private static func filter(
        _ all: [LibraryExercise],
        query: String,
        bodyPart: String?,
        equipment: String?
    ) -> [LibraryExercise] {
        let q = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return all.filter { ex in
            if let bodyPart, ex.bodyPart != bodyPart { return false }
            if let equipment, ex.equipment != equipment { return false }
            if !q.isEmpty, !ex.searchHaystack.contains(q) { return false }
            return true
        }
    }
}
