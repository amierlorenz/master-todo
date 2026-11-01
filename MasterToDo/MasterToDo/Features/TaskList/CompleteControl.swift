import SwiftUI

/// How the date circle completes a task: hover then click on Mac; on iOS a slide left, or two taps
/// when the "Tap to complete" setting is on.
struct CompleteControl: ViewModifier {
    static let tapToCompleteKey = "tapToComplete"
    static let threshold = 0.75

    let isEnabled: Bool
    let maxDrag: CGFloat
    @Binding var drag: CGFloat
    @Binding var isArmed: Bool
    @Binding var isPastThreshold: Bool
    let complete: () -> Void
    @AppStorage(Self.tapToCompleteKey) private var tapToComplete = false

    @ViewBuilder
    func body(content: Content) -> some View {
        #if os(macOS)
        content
            .onHover { hovering in withAnimation(.snappy) { isArmed = hovering && isEnabled } }
            .onTapGesture { if isEnabled { complete() } }
        #else
        if tapToComplete {
            content
                .onTapGesture {
                    guard isEnabled else { return }
                    if isArmed { complete() } else { withAnimation(.snappy(duration: 0.15)) { isArmed = true } }
                }
                .task(id: isArmed) {
                    guard isArmed, isEnabled else { return }
                    try? await Task.sleep(for: .seconds(3))
                    if !Task.isCancelled, isEnabled { withAnimation(.snappy) { isArmed = false } }
                }
        } else {
            content
                .gesture(slide, including: isEnabled ? .all : .subviews)
                .sensoryFeedback(trigger: isPastThreshold) { _, isPast in isPast ? .impact(weight: .medium) : nil }
        }
        #endif
    }

    private var slide: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                if !isArmed { withAnimation(.snappy(duration: 0.15)) { isArmed = true } }
                drag = min(0, max(value.translation.width, -maxDrag))
                isPastThreshold = -drag > maxDrag * Self.threshold
            }
            .onEnded { _ in
                if isPastThreshold {
                    complete()
                } else {
                    withAnimation(.spring) { drag = 0; isArmed = false }
                }
                isPastThreshold = false
            }
    }
}
