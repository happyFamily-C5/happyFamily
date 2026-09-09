import SwiftUI

struct CancelBookingSheet: View {
    let onConfirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image("cancelDonate")
                .resizable()
                .scaledToFit()
                .frame(width: 80)

            VStack(alignment: .leading, spacing: 8) {
                Text("Batalkan Booking")
                    .font(.title)
                    .bold()

            Text("Setelah dibatalkan, kamu perlu membuat pemesanan baru jika ingin melanjutkan kembali.")
                .font(.body)
            

            Text("Tindakan ini tidak dapat dibatalkan")
                .font(.footnote)
                .foregroundStyle(.red)
            }

            Spacer()

            SwipeToCancelBookingButton(onComplete: onConfirm)
        }
        .padding(24)
    }
}

private struct SwipeToCancelBookingButton: View {
    let onComplete: () -> Void

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

                Text("Hapus Booking")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
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
    CancelBookingSheet {
        print("Booking canceled")
    }
}
