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

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 16) {
                // MARK: - Banner

                ScrollView(showsIndicators: true) {
                    BannerEvent(image: .none)
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
                            dayLeft: 3
                        )

                        // MARK: - Location

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Location")
                                .font(.body).bold()

                            Divider()

                            LocationDisclosureCard(
                                name: "Eco Touch Office",
                                address: "Jl. Arjuna Utara No.14D, RT.1/RW.1, Tj. Duren Sel., Kec. Grogol petamburan, Kota Jakarta Barat,, Daerah Khusus Ibukota Jakarta 11470",
                                distance: 1.4
                            )
                        }

                        MapView(
                            coordinate: CLLocationCoordinate2D(
                                latitude: -6.1667,
                                longitude: 106.7900
                            )
                        )
                        .frame(height: 180)
                        .clipShape(
                            RoundedRectangle(cornerRadius: 28)
                        )

                        Spacer()
                    }
                    .padding(.horizontal, 20)
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
        maxCapacity: 500
    )
    .environment(AppRouter())
}
