//
//  ProgressBarCard.swift
//  happyFamily
//
//  Created by Gracia Adonay Efendi on 28/08/26.
//

import SwiftUI

struct ProgressBarCard: View {
    let value: Double
    let total: Double

    private var progressValue: Double {
        min(max(value, 0), total)
    }

    init(value: Double = 36, total: Double = 40) {
        self.value = value
        self.total = total
    }

    var body: some View {
        ProgressView(value: progressValue, total: total)
            .progressViewStyle(.linear)
            .tint(Color("2-BoldDarkSoftCyan"))
    }
}

#Preview("Progress Bar Card") {
    VStack {
        ProgressBarCard()
    }
    .padding()
}
