//
//  LandingPalette.swift
//  happyFamily
//
//  Created by Calzy Akmal Indyramdhani on 27/08/26.
//

import SwiftUI

enum LandingPalette {
    static let gradientTop = Color(red: 0.816, green: 0.898, blue: 0.878)
    static let gradientMid = Color(red: 0.937, green: 0.957, blue: 0.929)
    static let gradientBottom = Color(red: 0.816, green: 0.878, blue: 0.835)

    static let pine = Color(red: 0.247, green: 0.420, blue: 0.384)
    static let ink = Color(red: 0.086, green: 0.129, blue: 0.118)
    static let inkSecondary = Color(red: 0.325, green: 0.396, blue: 0.376)
    static let paper = Color.white

    static let backdrop = LinearGradient(
        stops: [
            .init(color: gradientTop, location: 0),
            .init(color: gradientMid, location: 0.46),
            .init(color: gradientBottom, location: 1),
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}
