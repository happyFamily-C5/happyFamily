//
//  EventDetailView.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 08/09/26.
//

import SwiftUI
import MapKit

struct SelectedEventDetailView: View {
    
    @Environment(AppRouter.self) var router
    
    var title: String
    var name: String
    var date: String
    var time: String
    
    let material = ["Katun", "linen", "Wool", "Tencel", "Rayon"]
    
    var body: some View {
        VStack() {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    VStack(spacing: 16){
                        
                        // MARK: - Banner
                        Image("Image 2")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 330,)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        
                        // MARK: - Title
                        VStack {
                            Text(title)
                                .font(.title).bold()
                                .multilineTextAlignment(.center)
                            Text(name)
                                .font(.headline).bold()
                        }
                        // MARK: - Date Time
                        VStack(spacing: 4) {
                            Text(date)
                                .font(.callout).bold()
                            Text(time)
                                .font(.callout).bold()
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 16) {
                        // MARK: - Donation Capacity
                        MaxDonationCard(maxCapacity: 5)
                        
                        // MARK: - Kriteria Donasi
                        Text("Kriteria Donasi")
                            .font(.body).bold()
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack{
                                ForEach(material, id: \.self) { material in
                                    Text(material)
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 16)
                                        .font(.footnote).bold()
                                        .background(Color(#colorLiteral(red: 0.9499571919, green: 0.9500558972, blue: 0.953115046, alpha: 1)), in: RoundedRectangle(cornerRadius: 16))
                                }
                            }
                        }
                        
                        // MARK: Lokasi
                        VStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Lokasi")
                                    .font(.body).bold()
                                
                                Divider()
                            }
                                
                                LocationDisclosureCard(
                                    name: "EcoTouch Office",
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
                        
                        // MARK: - Deskripsi
                        VStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Deskripsi Acara")
                                    .font(.body).bold()
                                
                                Divider()
                            }
                            
                            Text("Lorem ipsum dolor sit amet consectetur adipiscing elit. Quisque faucibus ex sapien vitae pellentesque sem placerat. In id cursus mi pretium tellus duis convallis. Tempus leo eu aenean sed diam urna tempor. Pulvinar vivamus fringilla lacus nec metus bibendum egestas. Iaculis massa nisl malesuada lacinia integer nunc posuere. \n\nUt hendrerit semper vel class aptent taciti sociosqu. Ad litora torquent per conubia nostra inceptos himenaeos.Lorem ipsum dolor sit amet consectetur adipiscing elit. Quisque faucibus ex sapien vitae pellentesque sem placerat. In id cursus mi pretium tellus duis convallis. Tempus leo eu aenean sed diam urna tempor. Pulvinar vivamus fringilla lacus nec metus bibendum egestas. Iaculis massa nisl malesuada lacinia integer nunc posuere. Ut hendrerit semper vel class aptent taciti sociosqu. Ad litora torquent per conubia nostra inceptos himenaeos.")
                        }
                    }

                    Spacer()
                    
                }
                
            }
            
            Button{
                router.push(to: .donationFlow)
            }label: {
                Text("Donasikan Pakaian")
                    .foregroundStyle(Color.white)
                    .font(.body).bold()
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .background(
                        AppColor.primaryCyan,
                        in: RoundedRectangle(cornerRadius: 60)
                    )
            }
            
        }
        .padding(.horizontal, 20)
        .toolbar{
            ToolbarItem(placement: .topBarTrailing) {
                Image(systemName: "square.and.arrow.up")
            }
            
            ToolbarItem(placement: .topBarLeading) {
                Image(systemName: "chevron.left")
            }
            
        }
    }
}

#Preview {
    NavigationStack {
        SelectedEventDetailView(
            title: "Ecoday Shirt | drop your unused shirt",
            name: "EcoTouch Indonesia",
            date: "9 Sept - 16 Sept 2026",
            time: "Hari Kerja · 09.00 - 16.00"
        )
        .environment(AppRouter())
    }
}
