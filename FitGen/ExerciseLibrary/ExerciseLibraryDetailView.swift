import SwiftUI

// MARK: - ExerciseLibraryDetailView
//
// Full detail for a catalog exercise: large looping GIF, muscle/equipment
// metadata and step-by-step instructions.

struct ExerciseLibraryDetailView: View {
    let exercise: LibraryExercise

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                ExerciseGIFView(urlString: exercise.gifUrl, cornerRadius: 22)
                    .frame(maxWidth: .infinity)
                    .frame(height: 280)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 22))

                // Metadata chips
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        MetaChip(icon: "figure.run", title: "Body Part", value: exercise.bodyPart)
                        MetaChip(icon: "target", title: "Target", value: exercise.targetMuscle)
                    }
                    HStack(spacing: 8) {
                        MetaChip(icon: "dumbbell", title: "Equipment", value: exercise.equipment)
                        if !exercise.secondaryMuscles.isEmpty {
                            MetaChip(icon: "circle.grid.2x2",
                                     title: "Secondary",
                                     value: exercise.secondaryMuscles.joined(separator: ", "))
                        }
                    }
                }

                // Instructions
                if !exercise.instructions.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("How to Perform", systemImage: "list.number")
                            .font(.headline)

                        ForEach(Array(exercise.instructions.enumerated()), id: \.offset) { idx, step in
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
            }
            .padding()
        }
        .navigationTitle(exercise.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - MetaChip

private struct MetaChip: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(value.muscleColor)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
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
}
