//
//  FormView.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 26/08/26.
//

import SwiftUI

struct FormView: View {
    var body: some View {
        VStack {
            HStack {
                Spacer()
                Text("Step 1 of 3")
                    .font(.headline)
            }
            
            Spacer()
        }.padding(20)
    }
}

#Preview {
    FormView()
        .environment(AppRouter())
    
}
