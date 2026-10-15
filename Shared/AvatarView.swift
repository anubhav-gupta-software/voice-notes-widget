import SwiftUI
import UIKit

struct AvatarView: View {
    var name: String
    var photoJPEG: Data?
    var size: CGFloat

    var body: some View {
        Group {
            if let photoJPEG, let image = UIImage(data: photoJPEG) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle()
                        .fill(AvatarPalette.color(for: name))
                    Text(NoteFormat.initials(name))
                        .font(.system(size: size * 0.36, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityLabel(name)
    }
}
