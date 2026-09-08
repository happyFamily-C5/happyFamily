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
    
    @State private var userLocation: String
    @State private var selectedAddress: String?
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    let title: String
    let manager: String
    let capacity: Int
    let maxCapacity: Int
    
    init(
        userLocation: String,
        title: String,
        manager: String,
        capacity: Int,
        maxCapacity: Int
    ) {
        _userLocation = State(initialValue: userLocation)
        self.title = title
        self.manager = manager
        self.capacity = capacity
        self.maxCapacity = maxCapacity
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 32) {
                VStack(alignment: .leading, spacing: 16) {
                    // MARK: - Header
                    Button {
                        router.openDonersMapPicker(
                            location: userLocation,
                            address: selectedAddress,
                            coordinate: selectedCoordinate
                        )
                    } label: {
                        HStack(spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "location.north.circle.fill")
                                    .font(.system(size: 20))
                                Text(userLocation)
                                    .bold()
                            }
                            Image(systemName: "chevron.down")
                                .font(.system(size: 17)).bold()
                            Spacer()
                        }
                        .foregroundStyle(.primary)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    
                    // MARK: - Intro
                    VStack(alignment: .leading, spacing: 4) {
                        Text("""
                            \(Text("Jelajahi ").font(.largeTitle).bold())\
                            \(Text("dan mulai").font(.largeTitle))\
                                \(Text("menjaga lingkungan").font(.largeTitle).bold())
                            """)
                        Text("Temukan acara yang cocok dengan kamu")
                            .font(.callout)
                    }
                }
                .padding(.horizontal, 20)
                
                ScrollView(showsIndicators: false) {
                    
                    //MARK: - Acara aktif
                    VStack(alignment: .leading, spacing: 32) {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Acara Aktif Kamu")
                                .font(.title2).bold()
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16){
                                    ForEach(0..<7){ _ in
                                        Button{
                                            
                                        } label : {
                                            Image("eventBanner")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 320, height: 180)
                                                .clipShape(RoundedRectangle(cornerRadius: 20))
                                        }
                                    }
                                    
                                }
                            }
                        }
                        
                        //MARK: - Untuk Kamu
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Text("Untuk Kamu")
                                    .font(.title2).bold()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 15)).bold()
                                    .foregroundStyle(Color.secondary)
                                Spacer()
                            }
                            ScrollView(.horizontal, showsIndicators: false){
                                HStack(spacing: 16){
                                    ForEach(0..<7){ _ in
                                        VStack(alignment: .leading, spacing: 8) {
                                            Button{
                                                
                                            }label: {
                                                Image("imageForyou")
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 180)
                                                
                                            }
                                            
                                            VStack {
                                                Text("Textile Market")
                                                    .font(.callout).bold()
                                                Text("EcoTouch Office")
                                                    .font(.footnote)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        //MARK: - Sedang Tren
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Text("Sedang Tren")
                                    .font(.title2).bold()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 15)).bold()
                                    .foregroundStyle(Color.secondary)
                                Spacer()
                            }
                            ScrollView(.horizontal, showsIndicators: false){
                                HStack(spacing: 16){
                                    ForEach(0..<7){ _ in
                                        VStack(alignment: .leading, spacing: 8) {
                                            Button{
                                                
                                            }label: {
                                                Image("sedangTrenImage")
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 180)
                                                
                                            }
                                            
                                            VStack {
                                                Text("Recycle Day")
                                                    .font(.callout).bold()
                                                Text("GBK Sudirman")
                                                    .font(.footnote)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .onChange(of: router.mapPickerSession.revision) { _, _ in
            if let location = router.mapPickerSession.selectedLocation {
                userLocation = location
            }
            selectedAddress = router.mapPickerSession.selectedAddress
            selectedCoordinate = router.mapPickerSession.selectedCoordinate
        }
    }
}

#Preview {
    HomeView(
        userLocation: "Jakarta Pusat",
        title: "Ecoday | Drop Your Unused Shirt",
        manager: "EcoTouch Indonesia",
        capacity: 250,
        maxCapacity: 500
    )
    .environment(AppRouter())
}
