//
//  TermsPage.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 08/09/26.
//

import SwiftUI

struct TermsPage: View {
    @Environment(\.presentationMode) var dismiss
    @Environment(AppRouter.self) var router
    
    @State var agreed = false
    
    var body: some View {
        VStack(spacing: 74) {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Terima Ketentuan")
                        .font(.title).bold()
                    Text("Harap baca dan setujui ketentuan berikut sebelum Kamu melanjutkan.")
                        .font(.body)
                }
                
                HStack(alignment: .top, spacing: 16){
                    Button{
                        agreed.toggle()
                    }label: {
                        Image(systemName: agreed ? "checkmark.square.fill" : "square")
                            .foregroundStyle(agreed ? .blue : .secondary)
                    }
                    
                    Text("Dengan melanjutkan, saya memahami bahwa pakaian yang saya serahkan dapat digunakan kembali, disalurkan, atau didaur ulang sesuai dengan kondisi dan kebutuhan pengelolaan tekstil.")
                        .font(.subheadline)
                        .multilineTextAlignment(.leading)
                        .foregroundStyle(.primary)
                    
                }
            }
            
            Button{
                router.push(to: .donationFlow)
                dismiss.wrappedValue.dismiss()
            }label: {
                Text("Setuju dan Lanjutkan")
                    .foregroundStyle(Color.white)
                    .font(.body).bold()
                    .padding(.vertical, 16)
                    .padding(.horizontal, 80)
                    .background(
                        agreed ? AppColor.primaryCyan : AppColor.primaryCyan
                            .opacity(0.7),
                        in: RoundedRectangle(cornerRadius: 60)
                    )
            }
            .disabled(!agreed)
        }
    }
}

#Preview {
    TermsPage()
        .environment(AppRouter())
}
