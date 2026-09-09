//
//  LeaveBookingProses.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 09/09/26.
//

import SwiftUI

struct LeaveBookingProses: View {
    @Environment(AppRouter.self) var router
    @Environment(\.presentationMode) var dismiss
    
    var body: some View {
        TabView {
                VStack(spacing: 16) {
                    VStack(spacing: 8){
                        Text("Yakin tidak ingin melanjutkan proses booking?")
                            .font(.title2).bold()
                            .multilineTextAlignment(.center)
                        Text("Data yang kamu isi tidak akan tersipman setelah kamu keluar dari proses ini")
                            .multilineTextAlignment(.center)
                    }
                    
                    Image("leaveDonationProses")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 199)
                }
        }
        .padding(.horizontal, 20)
        .tabViewStyle(.page)
        
        Button{
            router.pop()
            dismiss.wrappedValue.dismiss()
        } label: {
            Text("Keluar")
                .foregroundStyle(Color.white)
                .font(.body).bold()
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
                .background(Color(#colorLiteral(red: 0.9455779195, green: 0.4718430638, blue: 0.4545334578, alpha: 1)), in: RoundedRectangle(cornerRadius:99))
            
        }.padding(.horizontal, 20)
        
    }
}

#Preview {
    LeaveBookingProses()
        .environment(AppRouter())
}
