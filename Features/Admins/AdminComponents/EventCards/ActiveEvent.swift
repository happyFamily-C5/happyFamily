//
//  ActiveEvent.swift
//  happyFamily
//
//  Created by Gracia Adonay Efendi on 28/08/26.
//

import SwiftUI

struct ActiveEvent: View {
    let title: String
    let count: Int

    init(title: String = "Active Events", count: Int = 2) {
        self.title = title
        self.count = count
    }

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .italic()

            Text("\(count)")
                .font(.system(size: 30, weight: .bold))
        }
        .foregroundStyle(AppColor.baseColor)
        .frame(maxWidth: .infinity, minHeight: 132)
        .background(Color("2-BoldDarkSoftCyan"))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

#Preview("Active Event") {
    ActiveEvent()
        .padding(.horizontal, 16)
}
