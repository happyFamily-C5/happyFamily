//
//  HomeView.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 24/08/26.
//

import MapKit
import SwiftUI

struct HomeView: View {
    @Environment(AppRouter.self) private var router

    let title: String
    let manager: String
    let capacity: Int
    let maxCapacity: Int
    let bannerURL: URL?
    let locationName: String
    let locationAddress: String
    let latitude: Double
    let longitude: Double
    let acceptsBookings: Bool
    /// Event end timestamp from resolve-event; drives the "X day left" badge.
    let endsAt: Date

    init(
        title: String,
        manager: String,
        capacity: Int,
        maxCapacity: Int,
        bannerURL: URL? = nil,
        locationName: String,
        locationAddress: String,
        latitude: Double,
        longitude: Double,
        acceptsBookings: Bool,
        endsAt: Date = .now
    ) {
        self.title = title
        self.manager = manager
        self.capacity = capacity
        self.maxCapacity = maxCapacity
        self.bannerURL = bannerURL
        self.locationName = locationName
        self.locationAddress = locationAddress
        self.latitude = latitude
        self.longitude = longitude
        self.acceptsBookings = acceptsBookings
        self.endsAt = endsAt
    }

    private var daysLeft: Int {
        let days = Calendar.current.dateComponents([.day], from: .now, to: endsAt).day ?? 0
        return max(0, days)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 16) {
                // MARK: - Banner

                ScrollView(showsIndicators: true) {
                    BannerEvent(image: Image("Image 2"), remoteURL: bannerURL)
                        .clipShape(RoundedRectangle(cornerRadius: 40))
                        .ignoresSafeArea()

                    // MARK: - Event Information

                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(title)
                                    .font(.title.bold())

                                Text(manager)
                                    .font(.headline)
                            }

                            Spacer()

                            HStack(spacing: 16) {
                                Button {} label: {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 24))
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        ProgressBar(
                            maxCapacity: maxCapacity,
                            currentCapacity: capacity,
                            dayLeft: daysLeft
                        )

                        // MARK: - Location

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Location")
                                .font(.body).bold()

                            Divider()

                            LocationDisclosureCard(
                                name: locationName,
                                address: locationAddress,
                                distance: 0
                            )
                        }

                        MapView(
                            coordinate: CLLocationCoordinate2D(
                                latitude: latitude,
                                longitude: longitude
                            ),
                            locationName: locationName
                        )
                        .frame(height: 180)
                        .clipShape(
                            RoundedRectangle(cornerRadius: 28)
                        )

                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .disabled(!acceptsBookings)
                    .opacity(acceptsBookings ? 1 : 0.55)
                }

                // MARK: - Tab-bar-style floating button

                VStack {
                    Button {
                        router.push(to: .donationFlow)
                    } label: {
                        Text("Send My Clothes")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(18)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 28)
                                    .fill(AppColor.primaryCyan)
                            )
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 24)
            }

            .frame(maxWidth: .infinity)
            .ignoresSafeArea()
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}

#Preview {
    HomeView(
        title: "Ecoday | Drop Your Unused Shirt",
        manager: "EcoTouch Indonesia",
        capacity: 250,
        maxCapacity: 500,
        locationName: "Eco Touch Office",
        locationAddress: "Jl. Arjuna Utara No.14D, Jakarta Barat",
        latitude: -6.1667,
        longitude: 106.7900,
        acceptsBookings: true,
        endsAt: .now.addingTimeInterval(3 * 24 * 60 * 60)
    )
    .environment(AppRouter())
}
