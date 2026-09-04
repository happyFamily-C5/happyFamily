//
//  ScanResultView.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 04/09/26.
//

import SwiftUI

struct ScanResultView: View {
    @ObservedObject var scanner: QRScannerViewModel
    @State var showWheel: Bool = false
    
    private var rows: [String] {
        guard let result = scanner.result else { return [] }
        return result.components(separatedBy: .newlines)
    }
    
    var body: some View {
        VStack {
            List{
                Section(header: Text("Detail Donasi")){
                    ForEach(rows, id: \.self) { row in
                        Text(row)
                    }
                }
                Section {
                    VStack(spacing: 0) {
                        Button {
                            withAnimation {
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
                        .buttonStyle(.plain)
                        
                        if showWheel {
                            Picker("Berat Aktual", selection: $scanner.actualWeight) {
                                ForEach(scanner.actualWeightOpt, id: \.self) { weight in
                                    Text("\(weight, specifier: "%.1f") kg")
                                        .tag(weight)
                                }
                            }
                            .pickerStyle(.wheel)
                            .clipped()
                        }
                    }
                }
                .listRowBackground(Color(#colorLiteral(red: 0.9655296206, green: 0.9720321298, blue: 0.9782348275, alpha: 1)))
            }
            .listStyle(.insetGrouped)
            .scrollDisabled(true)
            .scrollContentBackground(.hidden)
            
            Spacer()
            
            Button{
                
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
                
            }label: {
                Text("Tolak")
                    .foregroundStyle(Color.white)
                    .font(.body).bold()
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(
                        Color.red,
                        in: RoundedRectangle(cornerRadius: 60)
                    )
            }.buttonStyle(.plain)
                .padding(.horizontal, 20)
            
        }
    }
}

#Preview {
    ScanResultView(scanner: QRScannerViewModel())
}
