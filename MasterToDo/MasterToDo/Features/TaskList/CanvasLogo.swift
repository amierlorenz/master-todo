import SwiftUI

/// Instructure's Canvas mark from Simple Icons (CC0 path), a template image so it takes the foreground color.
struct CanvasLogo: View {
    let size: CGFloat

    var body: some View {
        Image("CanvasLogo").resizable().scaledToFit().frame(width: size, height: size)
    }
}
