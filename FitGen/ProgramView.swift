import SwiftUI

struct ProgramView: View {
    @AppStorage("userName")      private var name = ""
    @AppStorage("userAge")       private var age = 25
    @AppStorage("userWeight")    private var weight = 70.0
    @AppStorage("userHeight")    private var height = 175.0
    @AppStorage("userGoal")      private var goal = "Weight Loss"
    @AppStorage("userActivity")  private var activityLevel = "Medium"
    @AppStorage("cachedProgram") private var cachedProgramJSON = ""

    @State private var program: WorkoutProgram?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var infoExercise: Exercise?
    @Environment(WorkoutSessionViewModel.self) private var viewModel

    private var currentUserProfile: UserFitnessProfile {
        let level: FitnessLevel
        switch activityLevel.lowercased() {
        case "low":  level = .beginner
        case "high": level = .advanced
        default:     level = .intermediate
        }
        return UserFitnessProfile(goal: goal, level: level, daysPerWeek: 5)
    }

    var body: some View {
        NavigationView {
            Group {
                if isLoading || viewModel.isLoadingResponse {
                    loadingView
                } else if let p = viewModel.activeProgram {
                    trainingProgramList(p)
                } else if let p = program {
                    programList(p)
                } else if let error = errorMessage {
                    errorView(error)
                } else {
                    loadingView
                }
            }
            .navigationTitle("My Program")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            await viewModel.loadProgram(profile: currentUserProfile, force: true)
                        }
                    } label: {
                        Label("Regenerate", systemImage: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoadingResponse)
                }
            }
        }
        .task { await viewModel.loadProgram(profile: currentUserProfile) }
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 90, height: 90)
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.green)
            }
            VStack(spacing: 6) {
                Text("Building your program…")
                    .font(.headline)
                Text("AI is designing your personalized plan")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ProgressView()
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 52))
                .foregroundStyle(.orange)
            VStack(spacing: 8) {
                Text("Couldn't generate program")
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button("Try Again") { Task { await regenerate() } }
                .buttonStyle(.borderedProminent)
                .tint(.green)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func programList(_ p: WorkoutProgram) -> some View {
        List {
            ForEach(p.days) { day in
                Section {
                    ForEach(Array(day.exercises.enumerated()), id: \.offset) { _, exercise in
                        NavigationLink(destination: ExerciseDetailView(exercise: exercise)) {
                            ExerciseRow(exercise: exercise)
                        }
                    }
                } header: {
                    DayHeader(day: day)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func trainingProgramList(_ p: TrainingProgram) -> some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(p.name)
                        .font(.headline)
                    Text("\(p.durationWeeks) haftalık · \(p.days.count) gün/hafta")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            ForEach(p.days) { day in
                Section {
                    ForEach(day.exercises) { exercise in
                        HStack(spacing: 14) {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.green.opacity(0.15))
                                .frame(width: 46, height: 46)
                                .overlay(
                                    Text(String(exercise.name.prefix(2)).uppercased())
                                        .font(.caption.bold())
                                        .foregroundStyle(.green)
                                )
                            VStack(alignment: .leading, spacing: 4) {
                                Text(exercise.name)
                                    .font(.body)
                                    .fontWeight(.medium)
                                Text("\(exercise.sets) sets · \(exercise.reps) reps · \(exercise.restSeconds)s rest")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                infoExercise = exercise
                            } label: {
                                Image(systemName: "info.circle")
                                    .font(.title3)
                                    .foregroundStyle(.green)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    HStack {
                        Text(day.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("\(day.exercises.count) exercises")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color(.systemGray5))
                            .clipShape(Capsule())
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .listStyle(.insetGrouped)
        .sheet(item: $infoExercise) { ex in
            ExerciseInfoSheet(
                exerciseName: ex.name,
                sets: ex.sets,
                reps: ex.reps,
                restSeconds: ex.restSeconds,
                notes: ex.notes
            )
        }
    }

    // MARK: - Logic

    private func loadOrGenerate() async {
        if !cachedProgramJSON.isEmpty, let parsed = parse(cachedProgramJSON) {
            program = parsed
            return
        }
        await regenerate()
    }

    private func regenerate() async {
        // Groq akışı devre dışı — karşılaştırma için korunuyor
        // let json = await GroqService.generateProgram(
        //     name: name, age: age, weight: weight,
        //     height: height, goal: goal, activityLevel: activityLevel
        // )
    }

    private func parse(_ json: String) -> WorkoutProgram? {
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(WorkoutProgram.self, from: data)
    }
}

// MARK: - DayHeader

private struct DayHeader: View {
    let day: WorkoutDay

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(day.day)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(day.focus)
                    .font(.caption)
                    .foregroundStyle(.green)
                    .fontWeight(.medium)
            }
            Spacer()
            Text("\(day.exercises.count) exercises")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color(.systemGray5))
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }
}

// MARK: - ExerciseRow

private struct ExerciseRow: View {
    let exercise: WorkoutExercise

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 10)
                .fill(exercise.muscle.muscleColor.opacity(0.15))
                .frame(width: 46, height: 46)
                .overlay(
                    Text(String(exercise.name.prefix(2)).uppercased())
                        .font(.caption.bold())
                        .foregroundStyle(exercise.muscle.muscleColor)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(.body)
                    .fontWeight(.medium)
                Text("\(exercise.sets) sets · \(exercise.reps) reps")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(exercise.muscle)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(exercise.muscle.muscleColor)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(exercise.muscle.muscleColor.opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ProgramView()
        .environment(WorkoutSessionViewModel())
}
