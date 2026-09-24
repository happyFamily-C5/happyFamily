//
//  ShimmerModifier.swift
//  happyFamily
//

import SwiftUI

/// Implementation detail of `View.skeleton(isLoading:)`: sweeps a subtle
/// left-to-right highlight band over the already-redacted content.
///
/// Not part of the public skeleton API — feature code should only use
/// `.skeleton(isLoading:)`. `internal` (not `private`) solely because
/// `SkeletonModifier.swift` applies it from its own file.
struct ShimmerModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Sweep position: `0` = band fully off-screen on the left,
    /// `1` = fully off-screen on the right.
    @State private var phase: CGFloat = 0

    private static let duration: TimeInterval = 1.4
    private static let bandWidthRatio: CGFloat = 0.6

    /// Highlight color only — the skeleton base color stays whatever
    /// `.redacted` paints, which adapts to light/dark mode automatically.
    private static let highlight = Color.white.opacity(0.4)

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { proxy in
                    let bandWidth = proxy.size.width * Self.bandWidthRatio
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: Self.highlight, location: 0.5),
                            .init(color: .clear, location: 1),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: bandWidth)
                    .offset(x: -bandWidth + phase * (proxy.size.width + bandWidth))
                }
                // Keep the highlight on the placeholder blocks only,
                // not on the transparent spacing between them.
                .mask { content }
            }
            .onAppear {
                startIfNeeded()
            }
            .onChange(of: reduceMotion) { _, _ in
                startIfNeeded()
            }
    }

    private func startIfNeeded() {
        guard !reduceMotion else {
            stopAnimation()
            return
        }
        withAnimation(.linear(duration: Self.duration).repeatForever(autoreverses: false)) {
            phase = 1
        }
    }

    private func stopAnimation() {
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            phase = 0
        }
    }
}
