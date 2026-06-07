import Foundation
import Observation

@MainActor
@Observable
final class WorkoutSessionViewModel {

    // MARK: - State

    var activeProgram: TrainingProgram?
    var currentDayIndex: Int = 0
    var currentExerciseIndex: Int = 0
    var currentSet: Int = 1
    var completedSets: [SetRecord] = []
    var chatMessages: [ChatMessage] = []
    var isLoadingResponse: Bool = false
    var errorMessage: String?

    // MARK: - Computed

    var currentDay: TrainingDay? {
        guard let program = activeProgram,
              currentDayIndex < program.days.count else { return nil }
        return program.days[currentDayIndex]
    }

    var currentExercise: Exercise? {
        guard let day = currentDay,
              currentExerciseIndex < day.exercises.count else { return nil }
        return day.exercises[currentExerciseIndex]
    }

    /// "Push antrenmanı, Incline Press, Set 3/4, önceki setler: 60kg x 10, 60kg x 9"
    var contextSummary: String {
        guard let day = currentDay, let exercise = currentExercise else {
            return "Henüz aktif antrenman yok."
        }
        let previous = completedSets
            .filter { $0.exerciseId == exercise.id }
            .map { "\($0.weight)kg x \($0.reps)" }
            .joined(separator: ", ")
        let previousText = previous.isEmpty ? "henüz set yok" : "önceki setler: \(previous)"
        return "\(day.name) antrenmanı, \(exercise.name), Set \(currentSet)/\(exercise.sets), \(previousText)"
    }

    // MARK: - Program Loading

    func reset() {
        activeProgram = nil
        currentDayIndex = 0
        currentExerciseIndex = 0
        currentSet = 1
        completedSets = []
        chatMessages = []
        errorMessage = nil
    }

    func loadProgram(profile: UserFitnessProfile, force: Bool = false) async {
        if !force {
            guard activeProgram == nil, !isLoadingResponse else { return }
        } else {
            guard !isLoadingResponse else { return }
        }
        isLoadingResponse = true
        defer { isLoadingResponse = false }

        do {
            activeProgram = try await GroqService.generateTrainingProgram(profile: profile)
            currentDayIndex = 0
            currentExerciseIndex = 0
            currentSet = 1
            completedSets = []
            chatMessages = []
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Coach Chat

    func askCoach(_ question: String) async {
        let userMessage = ChatMessage(role: "user", content: question)
        chatMessages.append(userMessage)

        isLoadingResponse = true
        defer { isLoadingResponse = false }

        let systemPrompt = """
        Sen bir AI fitness koçusun. Kısa ve net yanıt ver (max 3 cümle).
        KULLANICI DURUMU: \(contextSummary)
        """

        let response = await GroqService.chat(messages: chatMessages, systemPrompt: systemPrompt)
        let assistantMessage = ChatMessage(role: "assistant", content: response)
        chatMessages.append(assistantMessage)
    }

    // MARK: - Session Control

    func completeSet(weight: Double, reps: Int) {
        guard let exercise = currentExercise else { return }
        let record = SetRecord(
            exerciseId: exercise.id,
            setNumber: currentSet,
            weight: weight,
            reps: reps,
            completedAt: Date()
        )
        completedSets.append(record)
        if currentSet < exercise.sets {
            currentSet += 1
        }
    }

    func advanceToNextExercise() {
        guard let day = currentDay else { return }
        currentSet = 1
        if currentExerciseIndex < day.exercises.count - 1 {
            currentExerciseIndex += 1
        } else {
            advanceToNextDay()
        }
    }

    func advanceToNextDay() {
        guard let program = activeProgram else { return }
        currentExerciseIndex = 0
        currentSet = 1
        if currentDayIndex < program.days.count - 1 {
            currentDayIndex += 1
        }
    }
}
