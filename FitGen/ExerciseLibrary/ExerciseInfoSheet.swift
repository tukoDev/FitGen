import SwiftUI

// MARK: - ExerciseInfoSheet
//
// Presented from the "i" button next to a program exercise. Looks the move up
// in the cached exercise library by name and shows its looping GIF + metadata
// + step-by-step instructions. Falls back to the program's own sets/reps/notes
// when no library match exists (or while the catalog is still loading).

struct ExerciseInfoSheet: View {
    let exerciseName: String
    var sets: Int? = nil
    var reps: String? = nil
    var restSeconds: Int? = nil
    var notes: String? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var match: LibraryExercise?
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    gifSection
                    programStats
                    if let match { metadata(match) }
                    instructionsSection
                }
                .padding()
            }
            .navigationTitle(exerciseName.capitalized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Kapat") { dismiss() }
                }
            }
            .task {
                match = await ExerciseStore.shared.resolveMatch(forName: exerciseName)
                isLoading = false
            }
        }
    }

    // MARK: GIF / placeholder

    @ViewBuilder
    private var gifSection: some View {
        if let match {
            ExerciseGIFView(urlString: match.gifUrl, cornerRadius: 22)
                .frame(maxWidth: .infinity)
                .frame(height: 260)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 22))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color(.secondarySystemBackground))
                VStack(spacing: 10) {
                    if isLoading {
                        ProgressView()
                        Text("Hareket aranıyor…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text("Bu hareket için animasyon bulunamadı")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()
            }
            .frame(height: 260)
        }
    }

    // MARK: Program stats (sets / reps / rest)

    @ViewBuilder
    private var programStats: some View {
        let chips = statChips
        if !chips.isEmpty {
            HStack(spacing: 8) {
                ForEach(chips, id: \.label) { chip in
                    VStack(spacing: 2) {
                        Text(chip.value)
                            .font(.headline)
                            .foregroundStyle(.green)
                        Text(chip.label)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }

    private var statChips: [(label: String, value: String)] {
        var result: [(String, String)] = []
        if let sets { result.append(("Set", "\(sets)")) }
        if let reps { result.append(("Tekrar", reps)) }
        if let restSeconds { result.append(("Dinlenme", "\(restSeconds)s")) }
        return result
    }

    // MARK: Library metadata

    private func metadata(_ ex: LibraryExercise) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                infoChip(icon: "figure.run", title: "Bölge", value: ex.bodyPart)
                infoChip(icon: "target", title: "Hedef Kas", value: ex.targetMuscle)
            }
            HStack(spacing: 8) {
                infoChip(icon: "dumbbell", title: "Ekipman", value: ex.equipment)
                if !ex.secondaryMuscles.isEmpty {
                    infoChip(icon: "circle.grid.2x2", title: "İkincil",
                             value: ex.secondaryMuscles.joined(separator: ", "))
                }
            }
        }
    }

    private func infoChip(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(value.muscleColor)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.caption2).foregroundStyle(.secondary)
                Text(value.isEmpty ? "—" : value.capitalized)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: Instructions / notes

    @ViewBuilder
    private var instructionsSection: some View {
        let steps = match?.instructions ?? []
        if !steps.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Label("Nasıl Yapılır", systemImage: "list.number")
                    .font(.headline)
                ForEach(Array(steps.enumerated()), id: \.offset) { idx, step in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(idx + 1)")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .frame(width: 24, height: 24)
                            .background(Color.green)
                            .clipShape(Circle())
                        Text(step)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(18)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }

        if let notes, !notes.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Label("Not", systemImage: "text.bubble")
                    .font(.headline)
                Text(notes)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}
