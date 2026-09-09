//
//  ForYouCard.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 09/09/26.
//

import SwiftUI

struct ForYouCard: View {
    var name: String
    var title: String
    var startDate: String
    var endDate: String
    var location: String
    
    var body: some View {
        HStack(spacing: 16){
            Image("Image 2")
                .resizable()
                .scaledToFit()
                .frame(width: 121)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            
            VStack(alignment: .leading, spacing: 0){
                Text(name)
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
                Text(title)
                    .font(.body).bold()
                HStack(spacing: 8){
                    Image(systemName: "calendar.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.secondary)
                    Text("\(startDate) - \(endDate) 2026")
                        .font(.footnote)
                        .foregroundStyle(Color.secondary)
                }
                
                HStack(spacing: 8){
                    Image(systemName: "location.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.secondary)
                    Text(location)
                        .font(.footnote)
                        .foregroundStyle(Color.secondary)
                }
            }
        }
    }
}

#Preview {
    ForYouCard(
        name: "EcoTouch Indonesia",
        title: "Ecoday Shirt | drop your unused shirt",
        startDate: "9 Sept",
        endDate: "16 Sept",
        location: "EcoTouch Office"
    )
}
