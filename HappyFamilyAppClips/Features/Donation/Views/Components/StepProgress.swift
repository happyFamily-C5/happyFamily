//
//  ProgressBar.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 27/08/26.
//

import SwiftUI

struct StepProgress: View {
    var currentStep: Int
    var totalStep: Int
    
    var body: some View {
        HStack{
            ForEach(0..<totalStep, id: \.self){ index in
                Capsule()
                    .fill(
                        index + 1 <= currentStep ? AppColor.primaryCyan : AppColor.secondaryCyan
                    )
                    .frame(height: 8)
            }
        }
    }
}

#Preview {
    StepProgress(currentStep: 1, totalStep: 3)
    StepProgress(currentStep: 2, totalStep: 3)
    StepProgress(currentStep: 3, totalStep: 3)
}
