import SwiftUI
import TodoKit

struct GuideSheet: View {
    static let hasSeenKey = "hasSeenGuide"

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    completeHint
                    section("Tap a task") {
                        row(Image(systemName: "hand.tap.fill").font(.title3).foregroundStyle(.tint), "Opens a menu to open it in Canvas, complete it, or remove it")
                    }
                    section("Icon") {
                        ForEach([TaskStatus.canvas, .userCreated, .dateChanged, .submitted, .notTurnedIn, .closed, .removedFromCanvas, .done], id: \.self) { status in
                            row(StatusIcon(status: status), status.isDismissible ? "\(status.label). Tap to dismiss." : status.label)
                        }
                    }
                    section("Date circle") {
                        row(dot(.red, solid: true), "Overdue, closing: Canvas still takes it, the circle counts down")
                        row(dot(.orange), "Overdue, no close date (or already closed)")
                        row(dot(.blue), "Due: time left today, the weekday this week, then the date")
                        row(dot(.gray), "No due date")
                    }
                    section("Filters") {
                        row(Image(systemName: "line.3.horizontal.decrease").font(.title3).foregroundStyle(.secondary),
                            "Tap a filter to narrow the list, tap it again to show everything. Submitted, Date changed, and Closed get their own row with actions for all of them at once.")
                    }
                }
                .padding()
            }
            .navigationTitle("How it works")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Got it", role: .confirm) { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 560)
        #endif
    }

    // Leads the sheet because it's the one gesture nobody discovers alone.
    private var completeHint: some View {
        HStack(spacing: 14) {
            ZStack(alignment: .trailing) {
                Capsule().fill(.green.opacity(0.15)).frame(width: 96, height: 44)
                Image(systemName: "checkmark").font(.headline).foregroundStyle(.white)
                    .frame(width: 38, height: 38).background(.green, in: .circle).padding(.trailing, 3)
                Image(systemName: "chevron.left.2").font(.caption.bold()).foregroundStyle(.green).padding(.trailing, 50)
            }
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                #if os(macOS)
                Text("Hover the circle, then click").font(.headline)
                Text("to complete a task").foregroundStyle(.secondary)
                #else
                Text("Slide the circle left").font(.headline)
                Text("to complete a task. Prefer tapping? Turn on Tap to complete in Settings.").foregroundStyle(.secondary)
                #endif
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular.tint(.green.opacity(0.1)), in: .rect(cornerRadius: 20))
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.title3.bold())
            content()
        }
    }

    private func row(_ icon: some View, _ text: String) -> some View {
        HStack(spacing: 14) {
            icon.frame(width: 32)
            Text(text).font(.subheadline).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func dot(_ color: Color, solid: Bool = false) -> some View {
        Circle().fill(color.opacity(solid ? 1 : 0.2)).frame(width: 26, height: 26)
    }
}

#Preview {
    GuideSheet()
}
