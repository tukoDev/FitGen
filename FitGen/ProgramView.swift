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

    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    loadingView
                } else if let program = program {
                    programList(program)
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
                        Task { await regenerate() }
                    } label: {
                        Label("Regenerate", systemImage: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                }
            }
        }
        .task { await loadOrGenerate() }
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

    // MARK: - Logic

    private func loadOrGenerate() async {
        if !cachedProgramJSON.isEmpty, let parsed = parse(cachedProgramJSON) {
            program = parsed
            return
        }
        await regenerate()
    }

    private func regenerate() async {
        isLoading = true
        errorMessage = nil
        program = nil

        let json = await GroqService.generateProgram(
            name: name, age: age, weight: weight,
            height: height, goal: goal, activityLevel: activityLevel
        )
        cachedProgramJSON = json

        if let parsed = parse(json) {
            program = parsed
        } else {
            errorMessage = "The AI response could not be parsed. Please try regenerating."
            cachedProgramJSON = ""
        }
        isLoading = false
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

#Preview { ProgramView() }
