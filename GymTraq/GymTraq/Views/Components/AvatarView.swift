import SwiftUI
import UIKit

/// Circular profile picture; falls back to the user's initial on an accent
/// gradient when no photo is set. Used on the Profile screen and Home header.
struct AvatarView: View {
    let user: User?
    var size: CGFloat = 56

    var body: some View {
        Group {
            if let pic = user?.profile_pic,
               let data = Data(base64Encoded: pic),
               let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    LinearGradient(colors: [Color.appAccent, Color.appAccentDeep],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                    if let first = user?.email.first {
                        Text(String(first).uppercased())
                            .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
                            .foregroundStyle(.black)
                    } else {
                        Image(systemName: "person.fill")
                            .font(.system(size: size * 0.42))
                            .foregroundStyle(.black.opacity(0.7))
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

extension UIImage {
    /// Downscale longest edge and JPEG-encode — keeps avatar uploads well under
    /// the server's 1 MB JSON body limit.
    func avatarJPEGData(maxDimension: CGFloat = 512, quality: CGFloat = 0.7) -> Data? {
        let scale = min(1, maxDimension / max(size.width, size.height))
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let resized = UIGraphicsImageRenderer(size: newSize).image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: quality)
    }
}
