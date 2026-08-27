//
//  HomeView.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 24/08/26.
//

import MapKit
import SwiftUI

struct HomeView: View {
    @State var isPressed = false
    
    @Environment(AppRouter.self) var router
    
    var title: String
    var manager: String
    var capacity: Int
    var maxCapacity: Int
    
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
                                    .font(Font.title.bold())
                                
                                Text(manager)
                                    .font(.headline)
                            }
                            
                            Spacer()
                            
                            HStack(spacing: 16) {
                                Button {
                                    // action
                                } label: {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 24))
                                }
                                .buttonStyle(.plain)
                                
                                Button {
                                    isPressed.toggle()
                                    print(isPressed)
                                } label: {
                                    Image(systemName: isPressed ? "bookmark.fill" : "bookmark")
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
                            
                            Text("EcoTouch Office")
                                .font(.subheadline).bold()
                            
                            HStack {
                                Text(
                                    "Jl. Arjuna Utara No.14D, RT.1/RW.1, Tj. Duren Sel., Kec. Grogol petamburan, " +
                                    "Kota Jakarta Barat,, Daerah Khusus Ibukota Jakarta 11470"
                                )
                                .font(.caption)
                                
                                Spacer()
                                
                                Text("1,4 Km")
                                    .bold()
                            }.frame(height: 48)
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
                        // Send clothes action
                        router.push(to: .donationForm)
                    } label: {
                        Text("Send My Clothes")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 24)
                
            }
            
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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

