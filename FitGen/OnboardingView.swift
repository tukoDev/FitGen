import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding = false
    @AppStorage("userName")     var name = ""
    @AppStorage("userAge")      var age = 25
    @AppStorage("userWeight")   var weight = 70.0
    @AppStorage("userHeight")   var height = 175.0
    @AppStorage("userGoal")     var goal = ""
    @AppStorage("userActivity") var activityLevel = "Medium"

    @Environment(WorkoutSessionViewModel.self) private var sessionViewModel

    @State var page = 0
    @State private var splashTab   = 0
    @State private var location    = ""
    @State private var daysPerWeek = ""

    private let validGoals = ["Build Muscle", "Gain Strength", "Burn Fat", "Mobility & Form", "General Health"]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            switch page {
            case 0:  splashScreen
            case 1:  nameScreen
            case 2:  experienceScreen
            case 3:  goalScreen
            case 4:  locationScreen
            case 5:  daysScreen
            case 6:  heightScreen
            case 7:  weightScreen
            default: loadingScreen
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Progress Bar

    private func progressBar(step: Int, total: Int = 7) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(Color(white: 0.15))
                Rectangle()
                    .fill(Color.green)
                    .frame(width: geo.size.width * CGFloat(step) / CGFloat(total))
                    .animation(.easeInOut(duration: 0.3), value: step)
            }
        }
        .frame(height: 3)
    }

    // MARK: - Screen 0: Splash

    private var splashScreen: some View {
        ZStack {
            LinearGradient(colors: [.black, Color(white: 0.08)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            TabView(selection: $splashTab) {
                splashSlide1.tag(0)
                splashSlide2.tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
    }

    private var splashSlide1: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 24) {
                Text("Record. Analyze. Improve.")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text("Film your lifts and let AI break down your technique.")
                    .font(.body)
                    .foregroundStyle(Color(white: 0.65))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 28)
            Spacer().frame(height: 48)
            VStack(spacing: 20) {
                featureRow(icon: "video.fill",  text: "Video-based form analysis")
                featureRow(icon: "figure.run",  text: "33 joints tracked")
                featureRow(icon: "shield.fill", text: "Injury prevention")
            }
            .padding(.horizontal, 28)
            Spacer()
            VStack(spacing: 20) {
                dotIndicator(active: splashTab)
                Button { withAnimation { splashTab = 1 } } label: {
                    Text("Next")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white)
                        .foregroundStyle(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 28)
            }
            .padding(.bottom, 52)
        }
    }

    private var splashSlide2: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 24) {
                Text("Your Complete Training Platform")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text("Form analysis, workout logging, AI plans — all in one app.")
                    .font(.body)
                    .foregroundStyle(Color(white: 0.65))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 28)
            Spacer().frame(height: 48)
            VStack(spacing: 20) {
                featureRow(icon: "brain.head.profile", text: "AI coaching & scoring")
                featureRow(icon: "dumbbell.fill",      text: "Built-in workout logger")
                featureRow(icon: "sparkles",           text: "Personalized training plans")
            }
            .padding(.horizontal, 28)
            Spacer()
            VStack(spacing: 20) {
                dotIndicator(active: splashTab)
                Button { withAnimation { page = 1 } } label: {
                    Text("Get Started")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.green)
                        .foregroundStyle(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 28)
            }
            .padding(.bottom, 52)
        }
    }

    // MARK: - Screen 1: Name

    private var nameScreen: some View {
        VStack(spacing: 0) {
            progressBar(step: 1)
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    screenHeader(tag: "ABOUT YOU", title: "What's your name?")

                    TextField("", text: $name, prompt: Text("Enter your name").foregroundStyle(Color(white: 0.4)))
                        .font(.title3)
                        .foregroundStyle(.white)
                        .padding(16)
                        .background(Color(white: 0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(name.isEmpty ? Color.clear : Color.green, lineWidth: 2)
                        )
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .submitLabel(.continue)
                        .onSubmit {
                            if !name.trimmingCharacters(in: .whitespaces).isEmpty {
                                withAnimation { page = 2 }
                            }
                        }

                    continueButton(disabled: name.trimmingCharacters(in: .whitespaces).isEmpty) {
                        withAnimation { page = 2 }
                    }
                }
                .padding(24)
                .padding(.bottom, 32)
            }
        }
    }

    // MARK: - Screen 2: Experience Level

    private var experienceScreen: some View {
        VStack(spacing: 0) {
            progressBar(step: 2)
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    screenHeader(tag: "EXPERIENCE LEVEL", title: "How long have you been\ntraining?")
                    VStack(spacing: 12) {
                        SelectionCard(icon: "figure.walk",                         title: "New to Lifting", subtitle: "Beginner (0-1 years)", isSelected: activityLevel == "Low")    { activityLevel = "Low" }
                        SelectionCard(icon: "figure.strengthtraining.traditional", title: "Intermediate",   subtitle: "1-3 years",           isSelected: activityLevel == "Medium") { activityLevel = "Medium" }
                        SelectionCard(icon: "figure.strengthtraining.functional",  title: "Advanced",       subtitle: "3+ years",            isSelected: activityLevel == "High")   { activityLevel = "High" }
                        SelectionCard(icon: "trophy.fill",                         title: "Pro / Coach",    subtitle: "Professional",        isSelected: activityLevel == "Pro")    { activityLevel = "Pro" }
                    }
                    continueButton(disabled: !["Low", "Medium", "High", "Pro"].contains(activityLevel)) {
                        withAnimation { page = 3 }
                    }
                }
                .padding(24)
                .padding(.bottom, 32)
            }
        }
    }

    // MARK: - Screen 3: Goal

    private var goalScreen: some View {
        VStack(spacing: 0) {
            progressBar(step: 3)
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    screenHeader(tag: "YOUR GOAL", title: "What is your primary focus?")
                    VStack(spacing: 12) {
                        SelectionCard(icon: "figure.strengthtraining.traditional", title: "Build Muscle",    subtitle: "We'll optimize feedback", isSelected: goal == "Build Muscle")    { goal = "Build Muscle" }
                        SelectionCard(icon: "dumbbell.fill",                       title: "Gain Strength",  subtitle: "We'll optimize feedback", isSelected: goal == "Gain Strength")   { goal = "Gain Strength" }
                        SelectionCard(icon: "flame.fill",                          title: "Burn Fat",       subtitle: "We'll optimize feedback", isSelected: goal == "Burn Fat")        { goal = "Burn Fat" }
                        SelectionCard(icon: "figure.flexibility",                  title: "Mobility & Form",subtitle: "We'll optimize feedback", isSelected: goal == "Mobility & Form") { goal = "Mobility & Form" }
                        SelectionCard(icon: "heart.fill",                          title: "General Health", subtitle: "We'll optimize feedback", isSelected: goal == "General Health")  { goal = "General Health" }
                    }
                    continueButton(disabled: goal.isEmpty) {
                        withAnimation { page = 4 }
                    }
                }
                .padding(24)
                .padding(.bottom, 32)
            }
        }
        .onAppear {
            if !validGoals.contains(goal) {
                goal = ""
            }
        }
    }

    // MARK: - Screen 4: Location

    private var locationScreen: some View {
        VStack(spacing: 0) {
            progressBar(step: 4)
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    screenHeader(tag: "YOUR SETUP", title: "Where do you train?")
                    VStack(spacing: 12) {
                        SelectionCard(icon: "dumbbell.fill",     title: "Full Gym",               subtitle: "Barbells, machines, cables & more",    isSelected: location == "Full Gym")   { location = "Full Gym" }
                        SelectionCard(icon: "house.fill",         title: "Home (Dumbbells/Bands)", subtitle: "Dumbbells, resistance bands, bench",   isSelected: location == "Home")       { location = "Home" }
                        SelectionCard(icon: "figure.walk",        title: "Bodyweight Only",        subtitle: "No equipment needed",                  isSelected: location == "Bodyweight") { location = "Bodyweight" }
                        SelectionCard(icon: "arrow.2.circlepath", title: "Mixed / Varies",         subtitle: "Different setups throughout the week", isSelected: location == "Mixed")      { location = "Mixed" }
                    }
                    continueButton(disabled: location.isEmpty) {
                        withAnimation { page = 5 }
                    }
                }
                .padding(24)
                .padding(.bottom, 32)
            }
        }
    }

    // MARK: - Screen 5: Days Per Week

    private var daysScreen: some View {
        VStack(spacing: 0) {
            progressBar(step: 5)
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    screenHeader(tag: "YOUR SCHEDULE", title: "How many days can you train?")
                    VStack(spacing: 12) {
                        SelectionCard(icon: "calendar",             title: "2-3 days / week", subtitle: "Great for beginners or recovery focus", isSelected: daysPerWeek == "2-3") { daysPerWeek = "2-3" }
                        SelectionCard(icon: "calendar.badge.clock", title: "3-4 days / week", subtitle: "Balanced training and recovery",       isSelected: daysPerWeek == "3-4") { daysPerWeek = "3-4" }
                        SelectionCard(icon: "flame.fill",           title: "4-5 days / week", subtitle: "Serious training commitment",          isSelected: daysPerWeek == "4-5") { daysPerWeek = "4-5" }
                        SelectionCard(icon: "bolt.fill",            title: "6+ days / week",  subtitle: "High-frequency athlete schedule",      isSelected: daysPerWeek == "6+")  { daysPerWeek = "6+" }
                    }
                    continueButton(disabled: daysPerWeek.isEmpty) {
                        withAnimation { page = 6 }
                    }
                }
                .padding(24)
                .padding(.bottom, 32)
            }
        }
    }

    // MARK: - Screen 6: Height

    private var heightScreen: some View {
        VStack(spacing: 0) {
            progressBar(step: 6)
            Spacer()
            screenHeader(tag: "CM", title: "How tall are you?")
                .padding(.horizontal, 28)
            Spacer().frame(height: 40)
            HStack(alignment: .center, spacing: 16) {
                Text("\(Int(height))")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .frame(minWidth: 110, alignment: .trailing)
                Text("cm")
                    .font(.title)
                    .foregroundStyle(Color(white: 0.4))
                VerticalRuler(value: $height, range: 140...220)
                    .frame(width: 72, height: 220)
            }
            Spacer()
            HStack {
                navCircleButton(icon: "chevron.left")             { withAnimation { page = 5 } }
                Spacer()
                navCircleButton(icon: "chevron.right", green: true) { withAnimation { page = 7 } }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 52)
        }
    }

    // MARK: - Screen 7: Weight

    private var weightScreen: some View {
        VStack(spacing: 0) {
            progressBar(step: 7)
            Spacer()
            screenHeader(tag: "KG", title: "What's your weight?")
                .padding(.horizontal, 28)
            Spacer().frame(height: 40)
            HStack(alignment: .center, spacing: 12) {
                Text("\(Int(weight))")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                Text("kg")
                    .font(.title)
                    .foregroundStyle(Color(white: 0.4))
            }
            Spacer().frame(height: 36)
            HorizontalRuler(value: $weight, range: 40...150)
                .frame(height: 70)
                .padding(.horizontal, 24)
            Spacer()
            HStack {
                navCircleButton(icon: "chevron.left")             { withAnimation { page = 6 } }
                Spacer()
                navCircleButton(icon: "chevron.right", green: true) { withAnimation { page = 8 } }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 52)
        }
    }

    // MARK: - Screen 8: Loading

    private var loadingScreen: some View {
        LoadingScreen(
            viewModel: sessionViewModel,
            profile: buildProfile()
        ) {
            hasCompletedOnboarding = true
        }
    }

    private func buildProfile() -> UserFitnessProfile {
        let level: FitnessLevel
        switch activityLevel.lowercased() {
        case "low":          level = .beginner
        case "high", "pro":  level = .advanced
        default:             level = .intermediate
        }
        let days: Int
        switch daysPerWeek {
        case "2-3": days = 3
        case "3-4": days = 4
        case "4-5": days = 5
        case "6+":  days = 6
        default:    days = 5
        }
        return UserFitnessProfile(goal: goal, level: level, daysPerWeek: days)
    }

    // MARK: - Shared helpers

    private func screenHeader(tag: String, title: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(tag)
                .font(.caption.bold())
                .foregroundStyle(Color.green)
                .kerning(1.5)
            Text(title)
                .font(.title2.bold())
                .foregroundStyle(.white)
        }
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .foregroundStyle(Color.green)
                .frame(width: 22)
            Text(text).foregroundStyle(Color(white: 0.85))
            Spacer()
        }
    }

    private func dotIndicator(active: Int) -> some View {
        HStack(spacing: 8) {
            ForEach(0..<2, id: \.self) { i in
                Circle()
                    .fill(i == active ? Color.white : Color(white: 0.3))
                    .frame(width: 8, height: 8)
                    .animation(.easeInOut, value: active)
            }
        }
    }

    private func continueButton(disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("Continue")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(disabled ? Color(white: 0.18) : Color.white)
                .foregroundStyle(disabled ? Color(white: 0.35) : Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(disabled)
        .animation(.easeInOut(duration: 0.2), value: disabled)
    }

    private func navCircleButton(icon: String, green: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(green ? Color.black : Color.white)
                .frame(width: 54, height: 54)
                .background(green ? Color.green : Color(white: 0.15))
                .clipShape(Circle())
        }
    }
}

// MARK: - SelectionCard

private struct SelectionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? Color.green.opacity(0.18) : Color(white: 0.17))
                        .frame(width: 46, height: 46)
                    Image(systemName: icon)
                        .foregroundStyle(isSelected ? Color.green : Color(white: 0.6))
                        .font(.system(size: 20))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color(white: 0.5))
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.green)
                        .font(.system(size: 20))
                }
            }
            .padding(16)
            .background(Color(white: 0.12))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.green : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - VerticalRuler

private struct VerticalRuler: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    @State private var lastValue: Double = 0

    var body: some View {
        Canvas { context, size in
            let center    = size.height / 2
            let spacing: CGFloat = 5
            let count     = Int(size.height / spacing / 2) + 4

            for offset in -count...count {
                let v = (value - Double(offset)).rounded()
                guard range.contains(v) else { continue }
                let y       = center + CGFloat(offset) * spacing
                let isMajor = Int(v) % 10 == 0
                let tickW: CGFloat = isMajor ? 28 : 14

                var tick = Path()
                tick.move(to:    CGPoint(x: size.width - tickW, y: y))
                tick.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(tick, with: .color(isMajor ? .white : Color(white: 0.28)), lineWidth: 1)

                if isMajor {
                    context.draw(
                        Text("\(Int(v))").font(.system(size: 10)).foregroundStyle(Color(white: 0.5)),
                        at: CGPoint(x: size.width - tickW - 5, y: y), anchor: .trailing
                    )
                }
            }

            var line = Path()
            line.move(to:    CGPoint(x: 0, y: center))
            line.addLine(to: CGPoint(x: size.width, y: center))
            context.stroke(line, with: .color(.green), lineWidth: 2)
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .onChanged { g in
                    let delta = -g.translation.height / 5.0
                    value = (min(range.upperBound, max(range.lowerBound, lastValue + delta))).rounded()
                }
                .onEnded { _ in lastValue = value }
        )
        .onAppear { lastValue = value }
    }
}

// MARK: - HorizontalRuler

private struct HorizontalRuler: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    @State private var lastValue: Double = 0

    var body: some View {
        Canvas { context, size in
            let center    = size.width / 2
            let spacing: CGFloat = 5
            let count     = Int(size.width / spacing / 2) + 4

            for offset in -count...count {
                let v = (value + Double(offset)).rounded()
                guard range.contains(v) else { continue }
                let x       = center + CGFloat(offset) * spacing
                let isMajor = Int(v) % 10 == 0
                let tickH: CGFloat = isMajor ? 28 : 16

                var tick = Path()
                tick.move(to:    CGPoint(x: x, y: 0))
                tick.addLine(to: CGPoint(x: x, y: tickH))
                context.stroke(tick, with: .color(isMajor ? .white : Color(white: 0.28)), lineWidth: 1)

                if isMajor {
                    context.draw(
                        Text("\(Int(v))").font(.system(size: 10)).foregroundStyle(Color(white: 0.5)),
                        at: CGPoint(x: x, y: tickH + 5), anchor: .top
                    )
                }
            }

            var line = Path()
            line.move(to:    CGPoint(x: center, y: 0))
            line.addLine(to: CGPoint(x: center, y: size.height - 14))
            context.stroke(line, with: .color(.green), lineWidth: 2)
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .onChanged { g in
                    let delta = -g.translation.width / 5.0
                    value = (min(range.upperBound, max(range.lowerBound, lastValue + delta))).rounded()
                }
                .onEnded { _ in lastValue = value }
        )
        .onAppear { lastValue = value }
    }
}

// MARK: - LoadingScreen

private struct LoadingScreen: View {
    let viewModel: WorkoutSessionViewModel
    let profile: UserFitnessProfile
    let onComplete: () -> Void

    private let steps = [
        "Analyzing your training profile...",
        "Setting up workout logger...",
        "Configuring AI form analysis...",
        "Building personalized plan engine...",
        "Finalizing your experience..."
    ]

    @State private var completedCount = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 48) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(Color.green)
                    .scaleEffect(2.0)

                Text("Building Your Plan")
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 18) {
                    ForEach(steps.indices, id: \.self) { i in
                        HStack(spacing: 14) {
                            if i < completedCount {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.green)
                                    .font(.system(size: 20))
                            } else {
                                Circle()
                                    .stroke(Color(white: 0.28), lineWidth: 1.5)
                                    .frame(width: 20, height: 20)
                            }
                            Text(steps[i])
                                .font(.subheadline)
                                .foregroundStyle(i < completedCount ? .white : Color(white: 0.38))
                        }
                        .animation(.easeInOut(duration: 0.25), value: completedCount)
                    }
                }
            }
            .padding(32)
        }
        .onAppear { startSequence() }
    }

    private func startSequence() {
        Task { await viewModel.loadProgram(profile: profile) }

        Task {
            for i in steps.indices {
                try? await Task.sleep(nanoseconds: 800_000_000)
                await MainActor.run { completedCount = i + 1 }
            }
            try? await Task.sleep(nanoseconds: 500_000_000)
            await MainActor.run { onComplete() }
        }
    }
}

#Preview {
    OnboardingView()
        .environment(WorkoutSessionViewModel())
}
