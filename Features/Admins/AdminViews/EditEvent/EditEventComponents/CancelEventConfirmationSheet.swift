import SwiftUI

struct CancelEventConfirmationSheet: View {
    var onConfirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 36, weight: .semibold))
                .foregroundColor(cancelRed)
                .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 8) {
                Text("Batalkan Acara")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)

                Text("Kami akan mengirim notifikasi kepada para donatur yang telah melakukan booking donasi")
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Tindakan ini tidak dapat dibatalkan")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(cancelRed)
            }

            SwipeToCancelEventButton(onComplete: onConfirm)
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
    }

    private var cancelRed: Color {
        Color(red: 0.78, green: 0.12, blue: 0.12)
    }
}

private struct SwipeToCancelEventButton: View {
    var onComplete: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var hasCompleted = false

    private let knobSize: CGFloat = 42
    private let buttonHeight: CGFloat = 48
    private let horizontalPadding: CGFloat = 3
    private let cancelRed = Color(red: 0.95, green: 0.38, blue: 0.40)

    var body: some View {
        GeometryReader { geometry in
            let maxOffset = max(0, geometry.size.width - knobSize - (horizontalPadding * 2))

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(cancelRed.opacity(0.85))

                Text("Hapus Acara")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: knobSize, height: knobSize)
                    .background(cancelRed)
                    .clipShape(Circle())
                    .offset(x: dragOffset + horizontalPadding)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                guard !hasCompleted else { return }
                                dragOffset = min(max(0, value.translation.width), maxOffset)
                            }
                            .onEnded { _ in
                                guard !hasCompleted else { return }

                                if dragOffset > maxOffset * 0.68 {
                                    hasCompleted = true
                                    withAnimation(.snappy) {
                                        dragOffset = maxOffset
                                    }
                                    onComplete()
                                } else {
                                    withAnimation(.snappy) {
                                        dragOffset = 0
                                    }
                                }
                            }
                    )
            }
        }
        .frame(height: buttonHeight)
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    CancelEventConfirmationSheet {
        print("Confirmed")
    }
}
