//
//  ScanResultView.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 04/09/26.
//

import SwiftUI

struct ScanResultView: View {
    @Environment(AdminEventStore.self) private var eventStore
    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) var router

    @ObservedObject var scanner: QRScannerViewModel
    @State var showWheel: Bool = false
    @State var showDonationSuccess = false
    @State var showDonationReject = false
    
    private var rows: [String] {
        guard let result = scanner.result else { return [] }
        return result.components(separatedBy: .newlines)
    }
    
    var bookingID: String {
        rows.first(where: { $0.hasPrefix("Booking ID:") })?
            .replacingOccurrences(of: "Booking ID:", with: "")
            .trimmingCharacters(in: .whitespaces) ?? ""
    }

    var name: String {
        rows.first(where: { $0.hasPrefix("Nama:") })?
            .replacingOccurrences(of: "Nama:", with: "")
            .trimmingCharacters(in: .whitespaces) ?? ""
    }

    var phone: String {
        rows.first(where: { $0.hasPrefix("No. Telp:") })?
            .replacingOccurrences(of: "No. Telp:", with: "")
            .trimmingCharacters(in: .whitespaces) ?? ""
    }
    
    var body: some View {
        VStack {
            VStack(spacing: 32) {
                VStack(spacing: 4){
                    Text("Nomor Booking")
                        .font(.body)
                    Text(bookingID)
                        .font(.largeTitle).bold()
                }
                
                VStack(spacing: 0) {
                    VStack(spacing: 16){
                        HStack(spacing: 16){
                            Image("Image 2")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            
                            VStack(alignment: .leading, spacing: 4){
                                Text("Ecoday | Drop Your Unused Shirt")
                                    .font(.title).bold()
                                Text("EcoTouch Indonesia")
                                    .font(.headline)
                            }
                        }
                    }
                    
                    
                    List{
                        Section{
                            HStack {
                                Text("Nama")
                                    .font(.body)
                                Spacer()
                                Text(name)
                                    .font(.body).bold()
                            }
                            
                            HStack {
                                Text("No Telepon")
                                    .font(.body)
                                Spacer()
                                Text(phone)
                                    .font(.body).bold()
                            }
                        }
                        .listRowBackground(Color(#colorLiteral(red: 0.9655296206, green: 0.9720321298, blue: 0.9782348275, alpha: 1)))
                        
                        Section {
                            VStack(spacing: 0) {
                                Button {
                                    withAnimation(.snappy) {
                                        showWheel.toggle()
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: "shippingbox.fill")
                                        Text("Berat Aktual")
                                        
                                        Spacer()
                                        
                                        Text("\(scanner.actualWeight,specifier: "%.1f") kg")
                                            .foregroundStyle(.secondary)
                                        
                                        Image(systemName: "chevron.up.chevron.down")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                if showWheel {
                                    Divider()
                                        .padding()
                                    Picker("Berat Aktual", selection: $scanner.actualWeight) {
                                        ForEach(scanner.actualWeightOpt, id: \.self) { weight in
                                            Text("\(weight, specifier: "%.1f") kg")
                                                .tag(weight)
                                        }
                                    }
                                    .frame(height: 100)
                                    .pickerStyle(.wheel)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                }
                            }
                        }
                        .listRowBackground(Color(#colorLiteral(red: 0.9655296206, green: 0.9720321298, blue: 0.9782348275, alpha: 1)))
                    }
                    .listStyle(.insetGrouped)
                    .scrollDisabled(true)
                    .scrollContentBackground(.hidden)
                }
            }
            .padding(.top, 32)
            
            Spacer()
            
            Button{
                eventStore.acceptDonation(
                        weight: scanner.actualWeight
                    )
                showDonationSuccess = true
            }label: {
                Text("Terima")
                    .foregroundStyle(Color.white)
                    .font(.body).bold()
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(
                        AppColor.primaryCyan,
                        in: RoundedRectangle(cornerRadius: 60)
                    )
            }.buttonStyle(.plain)
                .padding(.horizontal, 20)
            
            Button{
                showDonationReject = true
            }label: {
                Text("Tolak")
                    .foregroundStyle(Color.white)
                    .font(.body).bold()
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(
                        Color(red: 0.78, green: 0.12, blue: 0.12),
                        in: RoundedRectangle(cornerRadius: 60)
                    )
            }.buttonStyle(.plain)
                .padding(.horizontal, 20)
            
        }
        
        .navigationTitle(Text("Detail Donasi"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showDonationSuccess) {
            AcceptDonationView{
                dismiss()
                router.popToRoot()
            }
        }
        .navigationDestination(isPresented: $showDonationReject) {
            RejectedDonationView{
                dismiss()
                router.popToRoot()
            }
        }
    }
}

#Preview {
    NavigationStack {
        ScanResultView(scanner: QRScannerViewModel())
            .environment(AdminEventStore())
            .environment(AppRouter())
    }
}
