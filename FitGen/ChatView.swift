import SwiftUI

struct ChatView: View {
    @AppStorage("userName")    private var name = ""
    @AppStorage("userAge")     private var age = 25
    @AppStorage("userWeight")  private var weight = 70.0
    @AppStorage("userHeight")  private var height = 175.0
    @AppStorage("userGoal")    private var goal = "Weight Loss"
    @AppStorage("userActivity") private var activityLevel = "Medium"

    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isTyping = false
    @FocusState private var inputFocused: Bool

    private var systemPrompt: String {
        """
        You are FitGen AI, a personal fitness coach. The user's profile:
        - Name: \(name)
        - Age: \(age) years old
        - Weight: \(weight) kg, Height: \(height) cm
        - Goal: \(goal)
        - Activity Level: \(activityLevel)
        Give concise, personalized, motivating fitness advice tailored to this exact profile.
        """
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Message list
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if messages.isEmpty {
                                WelcomePromptView(name: name)
                                    .padding(.top, 40)
                            }

                            ForEach(messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }

                            if isTyping {
                                HStack {
                                    TypingIndicatorView()
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .id("typing")
                            }
                        }
                        .padding(.vertical, 12)
                    }
                    .onChange(of: messages.count) {
                        withAnimation {
                            if let last = messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                    .onChange(of: isTyping) {
                        if isTyping {
                            withAnimation { proxy.scrollTo("typing", anchor: .bottom) }
                        }
                    }
                }

                Divider()

                // Input bar
                HStack(spacing: 10) {
                    TextField("Ask your coach…", text: $inputText, axis: .vertical)
                        .lineLimit(1...4)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .focused($inputFocused)

                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(canSend ? Color.green : Color.secondary)
                    }
                    .disabled(!canSend)
                    .animation(.easeInOut(duration: 0.15), value: canSend)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(Color(.systemBackground))
            }
            .navigationTitle("AI Coach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !messages.isEmpty {
                        Button("Clear") {
                            withAnimation { messages.removeAll() }
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
        }
    }

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isTyping
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isTyping else { return }

        let userMsg = ChatMessage(role: "user", content: text)
        withAnimation { messages.append(userMsg) }
        inputText = ""
        isTyping = true
        inputFocused = false

        Task {
            let reply = await GroqService.chat(messages: messages, systemPrompt: systemPrompt)
            withAnimation {
                isTyping = false
                messages.append(ChatMessage(role: "assistant", content: reply))
            }
        }
    }
}

// MARK: - MessageBubble

private struct MessageBubble: View {
    let message: ChatMessage
    private var isUser: Bool { message.role == "user" }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 60) }

            if !isUser {
                Circle()
                    .fill(Color.green)
                    .frame(width: 30, height: 30)
                    .overlay(
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.white)
                    )
            }

            Text(message.content)
                .font(.body)
                .foregroundStyle(isUser ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(isUser ? Color.green : Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .textSelection(.enabled)

            if !isUser { Spacer(minLength: 60) }
        }
        .padding(.horizontal)
    }
}

// MARK: - TypingIndicatorView

private struct TypingIndicatorView: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .frame(width: 8, height: 8)
                    .foregroundStyle(Color.secondary.opacity(0.7))
                    .offset(y: animating ? -4 : 4)
                    .animation(
                        .easeInOut(duration: 0.45)
                        .repeatForever(autoreverses: true)
                        .delay(Double(i) * 0.12),
                        value: animating
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .onAppear { animating = true }
    }
}

// MARK: - WelcomePromptView

private struct WelcomePromptView: View {
    let name: String

    private let suggestions = [
        "What should I eat to gain muscle?",
        "How do I improve my squat form?",
        "Create a 15-min ab workout for me",
        "Tips for improving my endurance"
    ]

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            VStack(spacing: 6) {
                Text("Hey, \(name.isEmpty ? "there" : name)!")
                    .font(.title2.bold())
                Text("Ask me anything about fitness,\nnutrition, or your program.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 8) {
                Text("Try asking:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(suggestions, id: \.self) { s in
                    Text("\"\(s)\"")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .italic()
                }
            }
        }
        .padding(.horizontal, 32)
    }
}

#Preview { ChatView() }
