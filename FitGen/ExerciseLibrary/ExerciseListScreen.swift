import SwiftUI

// MARK: - ExerciseListScreen
//
// Sample usage screen tying everything together:
//   • searchable list of ExerciseCards
//   • body-part + equipment filters
//   • lazy rendering with incremental paging
//   • offline-first (shows cache instantly) with sync/error states

struct ExerciseListScreen: View {
    @StateObject private var vm = ExerciseLibraryViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if vm.isEmpty && vm.isSyncing {
                    loadingState
                } else if vm.isEmpty {
                    emptyState
                } else {
                    listContent
                }
            }
            .navigationTitle("Exercises")
            .searchable(text: $vm.searchText, prompt: "Search exercises, muscles…")
            .toolbar { filterToolbar }
            .task { await vm.onAppear() }
            .refreshable { await vm.retry() }
        }
    }

    // MARK: List

    private var listContent: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                filterBar

                if vm.filtered.isEmpty {
                    ContentUnavailableView.search
                        .padding(.top, 60)
                } else {
                    ForEach(vm.visible) { ex in
                        NavigationLink(value: ex) {
                            ExerciseCard(exercise: ex)
                        }
                        .buttonStyle(.plain)
                        .onAppear { vm.loadMoreIfNeeded(current: ex) }
                    }

                    if vm.canLoadMore {
                        ProgressView()
                            .padding()
                    } else {
                        Text("\(vm.totalCount) exercises")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 12)
        }
        .navigationDestination(for: LibraryExercise.self) { ex in
            ExerciseLibraryDetailView(exercise: ex)
        }
    }

    // MARK: Filter bar (active chips + clear)

    @ViewBuilder
    private var filterBar: some View {
        if vm.hasActiveFilters {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if let part = vm.selectedBodyPart {
                        activeChip("Body: \(part.capitalized)") { vm.selectedBodyPart = nil }
                    }
                    if let gear = vm.selectedEquipment {
                        activeChip("Gear: \(gear.capitalized)") { vm.selectedEquipment = nil }
                    }
                    Button("Clear all", action: vm.clearFilters)
                        .font(.caption.weight(.semibold))
                }
            }
            .padding(.top, 4)
        }
    }

    private func activeChip(_ text: String, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: 4) {
            Text(text).font(.caption.weight(.semibold))
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.green.opacity(0.15))
        .foregroundStyle(.green)
        .clipShape(Capsule())
    }

    // MARK: Toolbar filter menus

    @ToolbarContentBuilder
    private var filterToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                filterMenuSection(
                    title: "Body Part",
                    values: vm.bodyParts,
                    selection: vm.selectedBodyPart
                ) { vm.selectedBodyPart = $0 }

                filterMenuSection(
                    title: "Equipment",
                    values: vm.equipmentTypes,
                    selection: vm.selectedEquipment
                ) { vm.selectedEquipment = $0 }

                if vm.hasActiveFilters {
                    Divider()
                    Button("Clear filters", role: .destructive, action: vm.clearFilters)
                }
            } label: {
                Image(systemName: vm.hasActiveFilters
                      ? "line.3.horizontal.decrease.circle.fill"
                      : "line.3.horizontal.decrease.circle")
            }
        }
    }

    @ViewBuilder
    private func filterMenuSection(
        title: String,
        values: [String],
        selection: String?,
        onSelect: @escaping (String?) -> Void
    ) -> some View {
        Menu(title) {
            Button {
                onSelect(nil)
            } label: {
                Label("All", systemImage: selection == nil ? "checkmark" : "")
            }
            ForEach(values, id: \.self) { v in
                Button {
                    onSelect(selection == v ? nil : v)
                } label: {
                    Label(v.capitalized, systemImage: selection == v ? "checkmark" : "")
                }
            }
        }
    }

    // MARK: States

    private var loadingState: some View {
        VStack(spacing: 14) {
            ProgressView()
            Text("Loading exercise library…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Exercises", systemImage: "dumbbell")
        } description: {
            Text(vm.syncError ?? "Connect to the internet to download the exercise library. It will then be available offline.")
        } actions: {
            Button("Retry") { Task { await vm.retry() } }
                .buttonStyle(.borderedProminent)
        }
    }
}

#Preview {
    ExerciseListScreen()
}
