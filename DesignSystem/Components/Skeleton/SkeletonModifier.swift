//
//  SkeletonModifier.swift
//  happyFamily
//

import SwiftUI

/// Marks a view as loading while keeping its exact layout: the content is
/// redacted into placeholders and a subtle shimmer sweeps across it.
///
/// Apply it to the *same* view that renders the loaded content so the loading
/// and loaded states share one layout and can never drift apart:
///
///     ForYouCard(...)
///         .skeleton(isLoading: model.isLoading)
///
/// `.redacted` only grays out views that already render something (text,
/// images), so image areas without a real image view should feed the skeleton
/// a sized shape instead:
///
///     RoundedRectangle(cornerRadius: 16)
///         .fill(Color.secondary.opacity(0.2))
///         .frame(height: 180)
///         .skeleton(isLoading: isLoading)
extension View {
    /// Shows `self` as a skeleton placeholder while `isLoading` is true;
    /// shows the untouched original view once loading finishes.
    @ViewBuilder
    func skeleton(isLoading: Bool) -> some View {
        if isLoading {
            modifier(SkeletonModifier())
        } else {
            self
        }
    }
}

/// Implementation detail of `View.skeleton(isLoading:)`.
/// Deliberately `private`: the extension above is the only entry point.
private struct SkeletonModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .redacted(reason: .placeholder)
            .modifier(ShimmerModifier())
            .allowsHitTesting(false)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Memuat konten")
    }
}

// MARK: - Previews

private struct SkeletonDemoCard: View {
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.secondary.opacity(0.2))
                .frame(height: 180)

            Text("Donasikan pakaianmu")
                .font(.headline)

            Text("Bantu kurangi limbah tekstil")
                .font(.subheadline)

            Text("Jakarta Selatan")
                .font(.caption)
        }
        .skeleton(isLoading: isLoading)
    }
}

private struct SkeletonToggleDemo: View {
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 16) {
            Toggle("Sedang memuat", isOn: $isLoading)
            SkeletonDemoCard(isLoading: isLoading)
        }
        .padding()
    }
}

#Preview("Loading — Light") {
    SkeletonDemoCard(isLoading: true)
        .padding()
}

#Preview("Loading — Dark") {
    SkeletonDemoCard(isLoading: true)
        .padding()
        .preferredColorScheme(.dark)
}


#Preview("Loading toggle") {
    SkeletonToggleDemo()
}
