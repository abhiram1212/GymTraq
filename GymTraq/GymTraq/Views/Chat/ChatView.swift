import SwiftUI

struct ChatView: View {
    @State private var vm = ChatViewModel()
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.appAccent,
                                         Color.appAccentDeep],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.black)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("AI Coach")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Your personal trainer")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.45))
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if vm.messages.isEmpty && !vm.isSending {
                            welcomePrompts
                        }
                        ForEach(vm.messages) { msg in
                            MessageBubble(message: msg)
                                .id(msg.id)
                        }
                        if vm.isSending {
                            TypingIndicator()
                                .id("typing")
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
                .scrollIndicators(.hidden)
                .refreshable { await vm.loadHistory() }
                // Dragging the conversation or tapping it dismisses the keyboard
                .scrollDismissesKeyboard(.interactively)
                .onTapGesture { inputFocused = false }
                .onChange(of: vm.messages.count) {
                    withAnimation {
                        if let lastId = vm.messages.last?.id {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: vm.isSending) {
                    if vm.isSending {
                        withAnimation { proxy.scrollTo("typing", anchor: .bottom) }
                    }
                }
            }

            // Error banner — a failed send restores the text; tell the user why
            if let err = vm.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle")
                    Text(err).font(.caption)
                    Spacer()
                    Button { vm.errorMessage = nil } label: {
                        Image(systemName: "xmark").font(.caption2.weight(.bold))
                    }
                }
                .foregroundStyle(Color.appDanger)
                .padding(10)
                .background(Color.appDanger.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, 16)
                .task(id: err) {
                    // Auto-dismiss after a few seconds; the input text is already restored
                    try? await Task.sleep(for: .seconds(5))
                    vm.errorMessage = nil
                }
            }

            // Input bar
            inputBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background { AnimatedBackground() }
        .task { await vm.loadHistoryIfNeeded() }
        .colorScheme(.dark)
    }

    // MARK: - Input bar

    private var inputBar: some View {
        @Bindable var bvm = vm
        return HStack(spacing: 12) {
            TextField("Ask your coach...", text: $bvm.inputText)
                .foregroundStyle(.white)
                .focused($inputFocused)
                // Return key reads "Send" and actually sends (multiline axis
                // swallows the return key as a newline, so single-line it is)
                .submitLabel(.send)
                .onSubmit {
                    inputFocused = false
                    Task { await vm.send() }
                }

            Button {
                inputFocused = false
                Task { await vm.send() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(
                        vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isSending
                            ? AnyShapeStyle(.white.opacity(0.2))
                            : AnyShapeStyle(LinearGradient(
                                colors: [Color.appAccent,
                                         Color.appAccentDeep],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ))
                    )
            }
            .disabled(vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isSending)
        }
        .padding(14)
        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .padding(.top, 8)
    }

    // MARK: - Welcome prompts

    private var welcomePrompts: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 44))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.appAccent,
                                 Color.appAccentDeep],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .padding(.top, 32)

            Text("Your AI Coach")
                .font(.title2.bold())
                .foregroundStyle(.white)
            Text("Ask about workouts, form, nutrition,\nor anything fitness related.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)

            VStack(spacing: 8) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button {
                        vm.inputText = suggestion
                        Task { await vm.send() }
                    } label: {
                        Text(suggestion)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(.white.opacity(0.07),
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(.white.opacity(0.1), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 16)
    }

    private let suggestions = [
        "What's a good chest workout for beginners?",
        "How should I improve my squat form?",
        "What should I eat after a heavy lifting session?",
        "How many rest days per week do I need?"
    ]
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ChatMessage
    var isUser: Bool { message.role == "user" }

    // Claude replies in markdown (**bold**, `code`, lists) — render it instead
    // of printing raw asterisks. Falls back to plain text if parsing fails.
    private var renderedText: AttributedString {
        (try? AttributedString(
            markdown: message.message,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .inlineOnlyPreservingWhitespace
            )
        )) ?? AttributedString(message.message)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 48) }

            if !isUser {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.appAccent,
                                         Color.appAccentDeep],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 28, height: 28)
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.black)
                }
            }

            // User bubble: accent with black text (Fitness CTA pairing);
            // AI bubble: flat card gray — iMessage-like hierarchy
            Text(renderedText)
                .font(.system(size: 15))
                .foregroundStyle(isUser ? Color.black : Color.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    isUser ? Color.appAccent : Color.appCard,
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )

            if !isUser { Spacer(minLength: 48) }
        }
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    @State private var animating = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.appAccent,
                                     Color.appAccentDeep],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 28, height: 28)
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.black)
            }
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(.white.opacity(0.5))
                        .frame(width: 7, height: 7)
                        .scaleEffect(animating ? 1.3 : 0.8)
                        .animation(
                            .easeInOut(duration: 0.4).repeatForever(autoreverses: true).delay(Double(i) * 0.15),
                            value: animating
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.appCard,
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            Spacer()
        }
        .onAppear { animating = true }
    }
}
