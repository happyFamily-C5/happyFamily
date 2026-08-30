//
//  BrandMark.swift
//  happyFamily
//
//  Created by Calzy Akmal Indyramdhani on 27/08/26.
//

import SwiftUI

/// The `.kumpul` spiral inside a filled disc — a garment's fibre being drawn
/// back in rather than thrown out.
struct BrandMark: View {
    var diameter: CGFloat

    var body: some View {
        Circle()
            .fill(LandingPalette.pine)
            .frame(width: diameter, height: diameter)
            .overlay {
                Spiral()
                    .stroke(
                        LandingPalette.paper,
                        style: StrokeStyle(lineWidth: diameter * 0.088, lineCap: .round)
                    )
                    .padding(diameter * 0.27)
            }
            .shadow(color: LandingPalette.pine.opacity(0.28), radius: 18, y: 10)
    }
}

private struct Spiral: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let maxRadius = min(rect.width, rect.height) / 2
        let turns = 1.55
        let steps = 140

        var path = Path()
        for step in 0 ... steps {
            let progress = Double(step) / Double(steps)
            let angle = progress * turns * 2 * .pi - .pi / 2
            let radius = maxRadius * (1 - progress * 0.78)
            let point = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
            if step == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        return path
    }
}

#Preview {
    ZStack {
        LandingPalette.backdrop.ignoresSafeArea()
        BrandMark(diameter: 76)
    }
}
