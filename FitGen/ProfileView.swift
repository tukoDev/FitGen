import SwiftUI

struct ProfileView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("userName")      private var name = ""
    @AppStorage("userAge")       private var age = 25
    @AppStorage("userWeight")    private var weight = 70.0
    @AppStorage("userHeight")    private var height = 175.0
    @AppStorage("userGoal")      private var goal = "Weight Loss"
    @AppStorage("userActivity")  private var activityLevel = "Medium"
    @AppStorage("cachedProgram") private var cachedProgram = ""

    @State private var showResetProgram = false
    @State private var showStartOver = false

    private let goals  = ["Weight Loss", "Muscle Gain", "Endurance"]
    private let levels = ["Low", "Medium", "High"]

    private var bmi: Double {
        let h = height / 100
        return h > 0 ? weight / (h * h) : 0
    }

    private var bmiCategory: String {
        switch bmi {
        case ..<18.5: return "Underweight"
        case 18.5..<25: return "Normal"
        case 25..<30: return "Overweight"
        default: return "Obese"
        }
    }

    private var bmiColor: Color {
        switch bmi {
        case ..<18.5: return .blue
        case 18.5..<25: return .green
        case 25..<30: return .orange
        default: return .red
        }
    }

    var body: some View {
        NavigationView {
            Form {
                // BMI
                Section {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("BMI").font(.caption).foregroundStyle(.secondary)
                            Text(String(format: "%.1f", bmi))
                                .font(.largeTitle.bold())
                                .foregroundStyle(bmiColor)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(bmiCategory)
                                .fontWeight(.semibold)
                                .foregroundStyle(bmiColor)
                            Text("Body Mass Index")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Personal Info
                Section(header: Text("Personal Info")) {
                    HStack {
                        Label("Name", systemImage: "person")
                        Spacer()
                        TextField("Name", text: $name)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.secondary)
                    }

                    Stepper("Age: \(age)", value: $age, in: 14...80)

                    HStack {
                        Label("Weight", systemImage: "scalemass")
                        Spacer()
                        TextField("70", value: $weight, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                            .foregroundStyle(.secondary)
                        Text("kg").foregroundStyle(.secondary)
                    }

                    HStack {
                        Label("Height", systemImage: "ruler")
                        Spacer()
                        TextField("175", value: $height, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                            .foregroundStyle(.secondary)
                        Text("cm").foregroundStyle(.secondary)
                    }
                }

                // Goal
                Section(header: Text("Fitness Goal")) {
                    Picker("Goal", selection: $goal) {
                        ForEach(goals, id: \.self) { Text($0) }
                    }
                }

                // Activity
                Section(header: Text("Activity Level")) {
                    Picker("Activity Level", selection: $activityLevel) {
                        ForEach(levels, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.segmented)
                }

                // Actions
                Section(footer: Text("Reset Program generates a fresh plan next time you visit the Program tab.")) {
                    Button("Reset Program") { showResetProgram = true }
                        .foregroundStyle(.orange)
                }

                Section(footer: Text("Start Over clears all your data and returns to onboarding.")) {
                    Button("Start Over", role: .destructive) { showStartOver = true }
                }
            }
            .navigationTitle("Profile")
            .confirmationDialog("Reset your program?",
                                isPresented: $showResetProgram,
                                titleVisibility: .visible) {
                Button("Reset Program", role: .destructive) { cachedProgram = "" }
                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog("Start over from scratch?",
                                isPresented: $showStartOver,
                                titleVisibility: .visible) {
                Button("Start Over", role: .destructive) {
                    cachedProgram = ""
                    hasCompletedOnboarding = false
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}

#Preview { ProfileView() }
