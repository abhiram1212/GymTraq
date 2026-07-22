import Foundation

@Observable
class ChatViewModel {
    var messages: [ChatMessage] = []
    var inputText = ""
    var isSending = false
    var errorMessage: String?

    private var hasLoaded = false

    /// Cache-first — switching to the Chat tab doesn't refetch history every time.
    func loadHistoryIfNeeded() async {
        guard !hasLoaded else { return }
        await loadHistory()
    }

    func loadHistory() async {
        do {
            messages = try await APIService.shared.getChatHistory()
            hasLoaded = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func send() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }
        inputText = ""
        errorMessage = nil
        isSending = true

        // Show the user's message immediately instead of waiting for a full history reload.
        // Negative id so it can't collide with server-assigned ids; replaced on next loadHistory.
        let tempId = -Int(Date().timeIntervalSince1970 * 1000)
        let optimistic = ChatMessage(
            message_id: tempId, message: text, role: "user",
            user_id: APIService.shared.userId ?? 0
        )
        messages.append(optimistic)

        do {
            let reply = try await APIService.shared.sendMessage(text)
            messages.append(reply)
        } catch {
            // Roll back and give the user their text back — never eat a typed message
            messages.removeAll { $0.message_id == tempId }
            inputText = text
            errorMessage = error.localizedDescription
        }
        isSending = false
    }
}
