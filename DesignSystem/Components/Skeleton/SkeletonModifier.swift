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

/// A geometry-only placeholder used to build loading layouts without fake
/// copy or fake domain models.
struct SkeletonBlock: View {
    var cornerRadius: CGFloat = 8

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.secondary.opacity(0.18))
    }
}

/// Displays a local or remote event image and keeps pending and failed states
/// visually distinct. The caller owns the frame and clipping.
struct LoadableEventImage: View {
    let localImage: Image?
    let remoteURL: URL?
    var contentMode: ContentMode = .fill
    var unavailableLabel = "Gambar tidak tersedia"

    var body: some View {
        Group {
            if let localImage {
                rendered(localImage)
            } else if let remoteURL {
                AsyncImage(url: remoteURL) { phase in
                    switch phase {
                    case .empty:
                        SkeletonBlock(cornerRadius: 0)
                            .skeleton(isLoading: true)
                    case let .success(image):
                        rendered(image)
                    case .failure:
                        UnavailableImagePlaceholder(label: unavailableLabel)
                    @unknown default:
                        UnavailableImagePlaceholder(label: unavailableLabel)
                    }
                }
            } else {
                UnavailableImagePlaceholder(label: unavailableLabel)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func rendered(_ image: Image) -> some View {
        image
            .resizable()
            .aspectRatio(contentMode: contentMode)
            .accessibilityHidden(true)
    }
}

private struct UnavailableImagePlaceholder: View {
    let label: String

    var body: some View {
        ZStack {
            Color(uiColor: .secondarySystemBackground)

            ViewThatFits(in: .vertical) {
                VStack(spacing: 6) {
                    Image(systemName: "photo")
                        .font(.title3)
                    Text(label)
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }

                Image(systemName: "photo")
                    .font(.title3)
            }
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
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
