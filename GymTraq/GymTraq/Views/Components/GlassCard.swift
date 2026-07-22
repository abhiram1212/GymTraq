import SwiftUI
import UIKit

extension View {
    /// .decimalPad has no return key, leaving users stuck with an undismissable
    /// keyboard — this adds a Done button above every keyboard in the view.
    func keyboardDoneButton() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil, from: nil, for: nil
                    )
                }
                .fontWeight(.semibold)
            }
        }
    }
}

// Flat elevated card, Apple-style: solid #1C1C1E, continuous corners, no strokes.
struct GlassCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background(Color.appCard, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct GlassButton: View {
    let title: String
    let icon: String?
    var isPrimary: Bool = true
    let action: () -> Void

    init(_ title: String, icon: String? = nil, isPrimary: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.isPrimary = isPrimary
        self.action = action
    }

    var body: some View {
        // Fitness-style CTA: bright accent capsule with black label
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon) }
                Text(title).fontWeight(.semibold)
            }
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(isPrimary ? Color.appAccent : Color.appCardElevated)
            .foregroundStyle(isPrimary ? Color.black : Color.white)
            .clipShape(Capsule())
        }
        .buttonStyle(PressableCardStyle())
    }
}

// Secure input with a reveal toggle. iOS wipes a SecureField's content when it
// regains focus and the user types — infuriating after a validation error. In
// revealed mode this is a plain TextField, which appends normally.
struct RevealableSecureField: View {
    let placeholder: String
    @Binding var text: String
    var contentType: UITextContentType = .password
    @State private var revealed = false

    var body: some View {
        HStack(spacing: 8) {
            Group {
                if revealed {
                    TextField(placeholder, text: $text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } else {
                    SecureField(placeholder, text: $text)
                }
            }
            .textContentType(contentType)

            Button { revealed.toggle() } label: {
                Image(systemName: revealed ? "eye.slash" : "eye")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .buttonStyle(.plain)
        }
    }
}

struct GlassTextField: View {
    let placeholder: String
    let icon: String
    var isSecure = false
    var isNewPassword = false // signup/reset: lets iOS offer a generated strong password
    @Binding var text: String

    private var isEmail: Bool { placeholder.lowercased().contains("email") }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.white.opacity(0.5))
                .frame(width: 20)
            if isSecure {
                RevealableSecureField(
                    placeholder: placeholder,
                    text: $text,
                    contentType: isNewPassword ? .newPassword : .password
                )
            } else {
                TextField(placeholder, text: $text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(isEmail ? .emailAddress : .default)
                    .textContentType(isEmail ? .emailAddress : nil)
            }
        }
        .foregroundStyle(.white)
        .padding(14)
        .background(Color.appCardElevated, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
