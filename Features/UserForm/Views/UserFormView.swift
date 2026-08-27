//
//  UserFormView.swift
//  happyFamily
//
//  Created by Hendra Irawan on 27/08/26.
//

import SwiftUI

struct UserFormView: View {
    @StateObject private var viewModel = UserFormViewModel()
    
    @Environment(\.dismiss)
    private var dismiss
    
    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea(edges: .all)
            
            ScrollView {
                VStack(
                    alignment: .leading,
                    spacing: 16
                ) {
                  
                }
            }
            
            
        }
    }
}


private extension UserFormView {
    var topNavigationBar: some View {
        HStack(spacing: 16) {
            Button{
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title3)
            }
            
            Spacer()
        }
    }
}
