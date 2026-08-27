//
//  RoundedTextField.swift
//  happyFamily
//
//  Created by Hendra Irawan on 27/08/26.
//

import SwiftUI

struct RoundedTextField: View {
     let placeholder: String
    @Binding var text: String
    
    var keyboardType: UIKeyboardType = .default
    
    var body: some View {
        
        TextField(
            "",
            text: $text,
            prompt: Text(placeholder)
                .foregroundStyle(Color.gray.opacity(0.5))
        )
        .keyboardType(keyboardType)
        .textInputAutocapitalization(
            keyboardType == .emailAddress ? .none : .sentences
        )
        .padding(.horizontal, 18)
        .frame(height: 52)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
        )
        .clipShape(
            RoundedRectangle(cornerRadius: 24)
        )
    }
}
