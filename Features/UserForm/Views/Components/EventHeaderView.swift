//
//  Untitled.swift
//  happyFamily
//
//  Created by Hendra Irawan on 27/08/26.
//

import SwiftUI


struct EventHeaderView: View {
    let event: Event
    var body: some View {
        HStack(spacing: 14) {
            Image(event.bannerImageName)
                .resizable()
                .scaledToFill()
                .frame(width: 108, height: 78)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 14
                    )
                )
            VStack(
                alignment: .leading,
                spacing: 5
            ) {
                Text(event.title)
                    .font(AppFont.cardTitle)
                    .foregroundStyle(AppColor.textColor)
                    .lineLimit(2)
                
                HStack(spacing: 4) {
                    Text(event.organizer)
                        .font(AppFont.organizerTitle)
                        .foregroundStyle(AppColor.textColor)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(AppFont.organizerTitle)
                        .foregroundColor(.green)
                }
            }
            
            Spacer()
        }
    }
    
}
