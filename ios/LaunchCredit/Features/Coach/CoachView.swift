import SwiftUI
import UIKit

/// The AI coach. Same conversation the site shows in its phone mock — but this
/// one is reading the member's real file: balances, dates, bills, plan.
struct CoachView: View {
    @EnvironmentObject private var state: AppState
    @State private var draft = ""
    @State private var showingSimulator = false

    var body: some View {
        NavigationStack {
            ZStack {
                Brand.s1.ignoresSafeArea()

                VStack(spacing: 0) {
                    header
                    transcript
                    suggestionBar
                    inputBar
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingSimulator) { SimulatorView() }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 11) {
            BrandMark(size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text("Launch Coach")
                    .font(BrandFont.heading(17))
                    .foregroundStyle(Brand.ink)
                HStack(spacing: 6) {
                    Circle().fill(Brand.greenBr).frame(width: 6, height: 6)
                    Text("Active now · knows your file")
                        .font(BrandFont.body(12.5, weight: .medium))
                        .foregroundStyle(Brand.dim)
                }
            }

            Spacer()

            Menu {
                Button("Clear conversation", systemImage: "trash") {
                    withAnimation { state.clearConversation() }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Brand.dim)
                    .frame(width: 36, height: 36)
                    .background(Brand.s2, in: Circle())
                    .overlay(Circle().stroke(Brand.line, lineWidth: 1))
            }
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.vertical, 12)
        .background(Brand.s2)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Brand.line).frame(height: 1)
        }
    }

    // MARK: - Transcript

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(state.messages) { message in
                        MessageBubble(message: message) { action in
                            run(action)
                        }
                        .id(message.id)
                    }

                    if state.coachIsTyping {
                        TypingIndicator().id(typingAnchor)
                    }
                }
                .padding(.horizontal, Metrics.gutter)
                .padding(.vertical, 18)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: state.messages.count) { _, _ in scrollToEnd(proxy) }
            .onChange(of: state.coachIsTyping) { _, _ in scrollToEnd(proxy) }
            .onAppear { scrollToEnd(proxy, animated: false) }
        }
    }

    private let typingAnchor = "typing-indicator"

    private func scrollToEnd(_ proxy: ScrollViewProxy, animated: Bool = true) {
        let target: AnyHashable? = state.coachIsTyping
            ? AnyHashable(typingAnchor)
            : state.messages.last.map { AnyHashable($0.id) }
        guard let target else { return }
        if animated {
            withAnimation(.easeOut(duration: 0.3)) { proxy.scrollTo(target, anchor: .bottom) }
        } else {
            proxy.scrollTo(target, anchor: .bottom)
        }
    }

    // MARK: - Suggestions

    @ViewBuilder
    private var suggestionBar: some View {
        let suggestions = state.messages.last?.role == .coach ? (state.messages.last?.suggestions ?? []) : []
        if !suggestions.isEmpty && !state.coachIsTyping {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button {
                            send(suggestion)
                        } label: {
                            Text(suggestion)
                                .font(BrandFont.body(14, weight: .semibold))
                                .foregroundStyle(Brand.greenDk)
                                .padding(.horizontal, 15)
                                .padding(.vertical, 10)
                                .background(Brand.wash, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Metrics.gutter)
                .padding(.bottom, 10)
            }
            .transition(.opacity)
        }
    }

    // MARK: - Input

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Ask me anything…", text: $draft, axis: .vertical)
                .font(BrandFont.body(16))
                .foregroundStyle(Brand.ink)
                .lineLimit(1...5)
                .padding(.horizontal, 18)
                .padding(.vertical, 13)
                .background(Brand.s1, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Brand.line2, lineWidth: 1))

            Button {
                send(draft)
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(canSend ? AnyShapeStyle(Brand.grad) : AnyShapeStyle(Brand.s3), in: Circle())
            }
            .disabled(!canSend)
            .accessibilityLabel("Send")
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(Brand.s2)
        .overlay(alignment: .top) {
            Rectangle().fill(Brand.line).frame(height: 1)
        }
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !state.coachIsTyping
    }

    /// The coach offered to do something; do it.
    private func run(_ action: CoachAction) {
        Haptics.tap()
        if case .openSimulator = action {
            showingSimulator = true
            return
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            state.perform(action)
        }
    }

    private func send(_ text: String) {
        let question = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !state.coachIsTyping else { return }
        draft = ""
        Task { await state.send(question) }
    }
}

// MARK: - Bubble

struct MessageBubble: View {
    let message: ChatMessage
    var onAction: (CoachAction) -> Void = { _ in }

    private var isCoach: Bool { message.role == .coach }

    var body: some View {
        VStack(alignment: isCoach ? .leading : .trailing, spacing: 8) {
            Text(formatted)
                .font(BrandFont.body(15.5))
                .foregroundStyle(isCoach ? Brand.ink : .white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    isCoach ? AnyShapeStyle(Brand.s3) : AnyShapeStyle(Brand.greenBr),
                    in: BubbleShape(isCoach: isCoach)
                )
                .frame(maxWidth: 300, alignment: isCoach ? .leading : .trailing)
                .textSelection(.enabled)

            if let attachment = message.attachment {
                AttachmentCard(attachment: attachment)
                    .frame(maxWidth: 300, alignment: .leading)
            }

            if let action = message.action {
                Button(action.label) { onAction(action) }
                    .buttonStyle(PrimaryButtonStyle(fullWidth: false))
            }
        }
        .frame(maxWidth: .infinity, alignment: isCoach ? .leading : .trailing)
    }

    /// The coach writes light markdown (`**bold**`); render it rather than
    /// showing the asterisks.
    private var formatted: AttributedString {
        (try? AttributedString(markdown: message.text)) ?? AttributedString(message.text)
    }
}

/// `.cm` — a chat bubble with one squared-off corner on the sender's side.
struct BubbleShape: Shape {
    let isCoach: Bool

    func path(in rect: CGRect) -> Path {
        Path(
            UIBezierPath(
                roundedRect: rect,
                byRoundingCorners: isCoach
                    ? [.topLeft, .topRight, .bottomRight]
                    : [.topLeft, .topRight, .bottomLeft],
                cornerRadii: CGSize(width: 18, height: 18)
            ).cgPath
        )
    }
}

/// `.cm-card` — the structured result card the coach attaches to some replies.
struct AttachmentCard: View {
    let attachment: ChatMessage.Attachment

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(attachment.title)
                    .font(BrandFont.body(13, weight: .semibold))
                    .foregroundStyle(Brand.dim)
                Spacer()
                Text(attachment.value)
                    .font(BrandFont.number(19))
                    .foregroundStyle(Brand.ink)
            }
            Text(attachment.subtitle)
                .font(BrandFont.body(12.5))
                .foregroundStyle(Brand.faint)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Brand.s2, in: RoundedRectangle(cornerRadius: Metrics.radiusTile, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Metrics.radiusTile, style: .continuous).stroke(Brand.line, lineWidth: 1))
    }
}

// MARK: - Typing

struct TypingIndicator: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Brand.faint)
                    .frame(width: 7, height: 7)
                    .opacity(animating ? 1 : 0.3)
                    .animation(
                        UIAccessibility.isReduceMotionEnabled
                            ? nil
                            : .easeInOut(duration: 0.5)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.16),
                        value: animating
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Brand.s3, in: BubbleShape(isCoach: true))
        .accessibilityLabel("Coach is typing")
        .onAppear { animating = true }
    }
}

#Preview {
    CoachView().environmentObject(AppState())
}
