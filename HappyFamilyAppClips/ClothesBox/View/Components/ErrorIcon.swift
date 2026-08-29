//
//  ErrorIcon.swift
//  Recap
//
//  Created by binc876 on 29/08/26.
//

import SwiftUI

struct ErrorIcon: View {
    var body: some View {
        Image(systemName: "xmark")
            .font(.largeTitle.bold())
            .foregroundStyle(.white)
            .frame(width: 88, height: 88)
            .background(Circle().fill(.red))
    }
}

#Preview {
    ErrorIcon()
}
