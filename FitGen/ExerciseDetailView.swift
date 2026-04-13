import SwiftUI
import SafariServices

// MARK: - ExerciseDetailView

struct ExerciseDetailView: View {
    let exercise: WorkoutExercise

    @State private var showVideo = false
    @State private var showFormChecker = false

    // Exercises supported by FormCheckerView
    private let formCheckKeywords = [
        "squat", "push-up", "pushup", "push up",
        "deadlift", "plank", "lunge",
        "shoulder press", "bicep curl",
        "sit-up", "situp", "sit up"
    ]

    private var supportsFormCheck: Bool {
        let lower = exercise.name.lowercased()
        return formCheckKeywords.contains { lower.contains($0) }
    }

    private var youtubeURL: URL {
        var components = URLComponents(string: "https://www.youtube.com/results")!
        components.queryItems = [
            URLQueryItem(name: "search_query",
                         value: "how to \(exercise.name) exercise form tutorial")
        ]
        return components.url!
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Hero card
                HStack(spacing: 16) {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(exercise.muscle.muscleColor.opacity(0.15))
                        .frame(width: 76, height: 76)
                        .overlay(
                            Image(systemName: "figure.strengthtraining.traditional")
                                .font(.system(size: 32))
                                .foregroundStyle(exercise.muscle.muscleColor)
                        )

                    VStack(alignment: .leading, spacing: 8) {
                        Text(exercise.muscle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            StatChip(value: "\(exercise.sets)", label: "Sets",
                                     icon: "repeat", color: .green)
                            StatChip(value: exercise.reps, label: "Reps",
                                     icon: "arrow.up.and.down", color: .blue)
                        }
                    }
                    Spacer()
                }
                .padding(18)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20))

                // Instructions
                VStack(alignment: .leading, spacing: 12) {
                    Label("How to Perform", systemImage: "list.number")
                        .font(.headline)

                    Text(exercise.instructions)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(18)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))

                // Watch on YouTube
                Button { showVideo = true } label: {
                    HStack {
                        Image(systemName: "play.rectangle.fill")
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Watch on YouTube")
                                .fontWeight(.semibold)
                            Text("How to \(exercise.name) — form tutorial")
                                .font(.caption)
                                .opacity(0.85)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .foregroundStyle(.white)
                    .padding()
                    .background(Color.red)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                // Check My Form (only for supported exercises)
                if supportsFormCheck {
                    Button { showFormChecker = true } label: {
                        HStack {
                            Image(systemName: "figure.walk.motion")
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Check My Form")
                                    .fontWeight(.semibold)
                                Text("Live AI pose analysis with your camera")
                                    .font(.caption)
                                    .opacity(0.85)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .foregroundStyle(.white)
                        .padding()
                        .background(Color.purple)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
            .padding()
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showVideo) {
            SafariView(url: youtubeURL)
                .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showFormChecker) {
            FormCheckerView(exerciseName: exercise.name)
        }
    }
}

// MARK: - StatChip

private struct StatChip: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - SafariView

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}
