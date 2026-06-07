import Foundation

// MARK: - Training Program

struct TrainingProgram: Codable, Identifiable {
    var id: String
    let name: String
    let durationWeeks: Int
    let days: [TrainingDay]

    enum CodingKeys: String, CodingKey {
        case id, name, durationWeeks, days
    }

    init(id: String = UUID().uuidString, name: String, durationWeeks: Int, days: [TrainingDay]) {
        self.id            = id
        self.name          = name
        self.durationWeeks = durationWeeks
        self.days          = days
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id            = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString
        self.name          = try container.decode(String.self, forKey: .name)
        self.durationWeeks = try container.decode(Int.self, forKey: .durationWeeks)
        self.days          = try container.decode([TrainingDay].self, forKey: .days)
    }
}

struct TrainingDay: Codable, Identifiable {
    var id: String
    let name: String
    let exercises: [Exercise]

    enum CodingKeys: String, CodingKey {
        case id, name, exercises
    }

    init(id: String = UUID().uuidString, name: String, exercises: [Exercise]) {
        self.id        = id
        self.name      = name
        self.exercises = exercises
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id        = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString
        self.name      = try container.decode(String.self, forKey: .name)
        self.exercises = try container.decode([Exercise].self, forKey: .exercises)
    }
}

struct Exercise: Codable, Identifiable {
    let id: String
    let name: String
    let sets: Int
    let reps: String
    let restSeconds: Int
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case id, name, sets, reps, restSeconds, notes
    }

    init(id: String = UUID().uuidString, name: String, sets: Int, reps: String, restSeconds: Int, notes: String?) {
        self.id          = id
        self.name        = name
        self.sets        = sets
        self.reps        = reps
        self.restSeconds = restSeconds
        self.notes       = notes
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id       = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        name     = try c.decode(String.self, forKey: .name)
        notes    = try? c.decode(String.self, forKey: .notes)

        // LLM bazen sets'i string döndürebilir
        if let i = try? c.decode(Int.self, forKey: .sets) {
            sets = i
        } else if let s = try? c.decode(String.self, forKey: .sets), let i = Int(s) {
            sets = i
        } else {
            sets = 3
        }

        // reps string veya int olabilir
        if let s = try? c.decode(String.self, forKey: .reps) {
            reps = s
        } else if let i = try? c.decode(Int.self, forKey: .reps) {
            reps = "\(i)"
        } else {
            reps = "10"
        }

        // restSeconds string veya int olabilir
        if let i = try? c.decode(Int.self, forKey: .restSeconds) {
            restSeconds = i
        } else if let s = try? c.decode(String.self, forKey: .restSeconds), let i = Int(s) {
            restSeconds = i
        } else {
            restSeconds = 60
        }
    }
}

// MARK: - Session Tracking

struct SetRecord: Codable {
    let exerciseId: String
    let setNumber: Int
    let weight: Double
    let reps: Int
    let completedAt: Date
}

// MARK: - User Profile

enum FitnessLevel: String, Codable, CaseIterable {
    case beginner     = "beginner"
    case intermediate = "intermediate"
    case advanced     = "advanced"

    var displayName: String {
        switch self {
        case .beginner:     return "Başlangıç"
        case .intermediate: return "Orta"
        case .advanced:     return "İleri"
        }
    }
}

struct UserFitnessProfile: Codable {
    let goal: String
    let level: FitnessLevel
    let daysPerWeek: Int
}
