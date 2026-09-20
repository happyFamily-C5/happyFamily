//
//  ForYouCard.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 09/09/26.
//

import SwiftUI

/// Event row used by the For You / Trending pages. `name` is the organiser
/// snapshot from `account:dashboard`; the banner loads from the public
/// event-banners bucket with a local placeholder fallback.
struct ForYouCard: View {
    var name: String = "EcoTouch Indonesia"
    var title: String
    var startDate: String
    var endDate: String
    var location: String
    var bannerURL: URL?

    var body: some View {
        HStack(spacing: 16) {
            banner
                .frame(width: 121, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 0) {
                Text(name)
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
                titleContent
                HStack(spacing: 8) {
                    Image(systemName: "calendar.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.secondary)
                    Text("\(startDate) - \(endDate)")
                        .font(.footnote)
                        .foregroundStyle(Color.secondary)
                }

                HStack(spacing: 8) {
                    Image(systemName: "location.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.secondary)
                    Text(location)
                        .font(.footnote)
                        .foregroundStyle(Color.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    /// Reserves the card's two-line title height for both loading and loaded states.
    /// The guide uses the system body font, so it follows Dynamic Type naturally.
    private var titleContent: some View {
        ZStack(alignment: .topLeading) {
            Text(verbatim: "Title\nTitle")
                .font(.body)
                .bold()
                .lineLimit(2)
                .hidden()
                .accessibilityHidden(true)

            Text(title)
                .font(.body)
                .bold()
                .lineLimit(2)
        }
    }

    private var banner: some View {
        LoadableEventImage(
            localImage: nil,
            remoteURL: bannerURL,
            unavailableLabel: "Banner acara tidak tersedia"
        )
    }
}

struct ForYouCardSkeleton: View {
    var body: some View {
        HStack(spacing: 16) {
            SkeletonBlock(cornerRadius: 16)
                .frame(width: 121, height: 84)

            VStack(alignment: .leading, spacing: 7) {
                SkeletonBlock(cornerRadius: 4)
                    .frame(width: 110, height: 12)
                SkeletonBlock(cornerRadius: 4)
                    .frame(maxWidth: .infinity)
                    .frame(height: 16)
                SkeletonBlock(cornerRadius: 4)
                    .frame(width: 130, height: 16)
                SkeletonBlock(cornerRadius: 4)
                    .frame(width: 120, height: 12)
                SkeletonBlock(cornerRadius: 4)
                    .frame(width: 100, height: 12)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    ForYouCard(
        title: "Ecoday Shirt | drop your unused shirt",
        startDate: "9 Sept",
        endDate: "16 Sept",
        location: "EcoTouch Office"
    )
}
