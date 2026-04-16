import Foundation

@Observable
class ChatViewModel {
    var messages: [ChatMessage] = []
    var inputText = ""
    var isSending = false
    var errorMessage: String?

    func loadHistory() async {
        do {
            messages = try await APIService.shared.getChatHistory()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func send() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        isSending = true
        do {
            let reply = try await APIService.shared.sendMessage(text)
            await loadHistory() // reload to show both user + assistant messages
            _ = reply
        } catch {
            errorMessage = error.localizedDescription
        }
        isSending = false
    }
}
