//
//  ProgressIndicator.swift
//  happyFamily
//
//  Created by Hendra Irawan on 27/08/26.
//

import SwiftUI

struct StepProgressView: View {
    let currentStep: Int
    let totalStep: Int
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...totalStep, id: \.self) { step in
                Capsule()
                    .fill(
                        step <= currentStep
                        ? AppColor.accentColor
                        : AppColor.baseColor
                    )
                    .frame(height: 10)
            }
        }
    }
    
}
