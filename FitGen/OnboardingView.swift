import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("userName")    private var name = ""
    @AppStorage("userAge")     private var age = 25
    @AppStorage("userWeight")  private var weight = 70.0
    @AppStorage("userHeight")  private var height = 175.0
    @AppStorage("userGoal")    private var goal = "Weight Loss"
    @AppStorage("userActivity") private var activityLevel = "Medium"

    @State private var page = 0

    private let goals  = ["Weight Loss", "Muscle Gain", "Endurance"]
    private let levels = ["Low", "Medium", "High"]

    var body: some View {
        ZStack(alignment: .top) {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress indicator
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { i in
                        Capsule()
                            .fill(i <= page ? Color.green : Color(.systemGray4))
                            .frame(width: i == page ? 28 : 10, height: 10)
                            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: page)
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 8)

                TabView(selection: $page) {
                    welcomePage.tag(0)
                    statsPage.tag(1)
                    goalsPage.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: page)
            }
        }
    }

    // MARK: - Page 1: Welcome + Name

    private var welcomePage: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer().frame(height: 24)

                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.green)

                VStack(spacing: 8) {
                    Text("Welcome to FitGen")
                        .font(.largeTitle.bold())
                    Text("Your AI-powered personal fitness coach")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("What's your name?")
                        .font(.headline)
                    HStack {
                        Image(systemName: "person")
                            .foregroundStyle(.secondary)
                        TextField("Your name", text: $name)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 24)

                primaryButton("Continue  →") {
                    withAnimation { page = 1 }
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 48)
        }
    }

    // MARK: - Page 2: Stats

    private var statsPage: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer().frame(height: 24)

                VStack(spacing: 8) {
                    Text("Your Stats")
                        .font(.largeTitle.bold())
                    Text("This helps us calibrate your program")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 14) {
                    statField(label: "Age", icon: "calendar") {
                        Stepper("\(age) years old", value: $age, in: 14...80)
                    }

                    statField(label: "Weight", icon: "scalemass") {
                        HStack {
                            TextField("70", value: $weight, format: .number)
                                .keyboardType(.decimalPad)
                            Text("kg").foregroundStyle(.secondary)
                        }
                    }

                    statField(label: "Height", icon: "ruler") {
                        HStack {
                            TextField("175", value: $height, format: .number)
                                .keyboardType(.decimalPad)
                            Text("cm").foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 24)

                navButtons(back: { withAnimation { page = 0 } },
                           next: { withAnimation { page = 2 } })
                    .padding(.horizontal, 24)
            }
            .padding(.bottom, 48)
        }
    }

    // MARK: - Page 3: Goals

    private var goalsPage: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer().frame(height: 24)

                VStack(spacing: 8) {
                    Text("Your Goals")
                        .font(.largeTitle.bold())
                    Text("Almost there — one last step!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 20) {
                    // Goal selection
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Primary Goal").font(.headline)
                        ForEach(goals, id: \.self) { g in
                            GoalOptionRow(
                                title: g,
                                icon: goalIcon(g),
                                isSelected: goal == g
                            ) { goal = g }
                        }
                    }

                    // Activity level
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Activity Level").font(.headline)
                        Picker("Activity Level", selection: $activityLevel) {
                            ForEach(levels, id: \.self) { Text($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                .padding(.horizontal, 24)

                HStack(spacing: 12) {
                    secondaryButton("← Back") { withAnimation { page = 1 } }
                    primaryButton("Generate My Program 🚀") {
                        hasCompletedOnboarding = true
                    }
                }
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 48)
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func statField<Content: View>(label: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(label, systemImage: icon).font(.headline)
            content()
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.secondarySystemBackground))
                .foregroundStyle(.primary)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private func navButtons(back: @escaping () -> Void, next: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            secondaryButton("← Back", action: back)
            primaryButton("Continue  →", action: next)
        }
    }

    private func goalIcon(_ g: String) -> String {
        switch g {
        case "Weight Loss": return "flame.fill"
        case "Muscle Gain": return "dumbbell.fill"
        default:            return "figure.run"
        }
    }
}

// MARK: - GoalOptionRow

private struct GoalOptionRow: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .foregroundStyle(isSelected ? .white : .green)
                    .frame(width: 24)
                Text(title)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? .white : .primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white)
                }
            }
            .padding()
            .background(isSelected ? Color.green : Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

#Preview { OnboardingView() }
