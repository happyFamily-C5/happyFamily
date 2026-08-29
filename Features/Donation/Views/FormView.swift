//
//  FormView.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 26/08/26.
//

import SwiftUI

struct FormView: View {
    
    @Environment(AppRouter.self) var router
    @State var name: String = ""
    @State var phoneNumber: String = ""
    
    let onNext: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 36) {
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
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Personal Information")
                        .font(Font.title.bold())
                    Divider()
                }
                VStack(alignment: .leading, spacing: 8){
                    Text("Name")
                        .font(.body)
                    TextField("Enter your name", text: $name)
                        .padding(20)
                        .background(Color.gray.opacity(0.2), in: RoundedRectangle(cornerRadius: 30))     
                }
                
                VStack(alignment: .leading, spacing: 8){
                    Text("Phone Number")
                        .font(.body)
                    TextField("Active phone number", text: $phoneNumber)
                        .keyboardType(.numberPad)
                        .padding(20)
                        .background(Color.gray.opacity(0.2), in: RoundedRectangle(cornerRadius: 30))
                }
            }
            Spacer()
            Button{
                onNext()
//                router.push(to: .scan)
            }label: {
                Text("Lanjut")
                    .padding()
                    .padding(.horizontal, 30)
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .background(
                        Color.green,
                        in: RoundedRectangle(cornerRadius: 30)
                    )
                
            }
            
        }
        .padding(20)
    }
}

#Preview {
    NavigationStack {
        FormView{}
            .environment(AppRouter())
    }

}
