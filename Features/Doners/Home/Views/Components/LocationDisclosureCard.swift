//
//  LocationDisclosureCard.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 29/08/26.
//

import SwiftUI

struct LocationDisclosureCard: View {
    var name: String
    var address: String
    var distance: Double

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isExpanded.toggle()
                }
            } label: {
                if isExpanded {
                    VStack(alignment: .leading) {
                        HStack {
                            Text(name)
                                .font(.headline).bold()
                            Image(systemName: "chevron.up")
                                .foregroundStyle(Color.secondary).bold()
                        }
                        HStack(alignment: .center) {
                            Text(address)
                                .font(.caption)
                            Spacer()
                            Text("\(distance, specifier: "%.1f") Km")
                                .font(.title2).bold()
                        }
                    }
                } else {
                    HStack {
                        Text(name)
                            .font(.headline).bold()
                        Image(systemName: "chevron.down")
                            .foregroundStyle(Color.secondary).bold()
                        Spacer()
                        Text("\(distance, specifier: "%.1f") Km")
                            .fontDesign(.none)
                            .font(.title2).bold()
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    LocationDisclosureCard(
        name: "Eco Touch Office",
        address: "Jl. Arjuna Utara No.14D, RT.1/RW.1, Tj. Duren Sel., Kec. Grogol petamburan, Kota Jakarta Barat,, Daerah Khusus Ibukota Jakarta 11470",
        distance: 1.4
    )
}
