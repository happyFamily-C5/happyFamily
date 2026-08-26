//
//  MapView.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 26/08/26.
//

import SwiftUI
import MapKit

struct MapView: View {
    
    let coordinate: CLLocationCoordinate2D
    
    var body: some View {
        Map(
            initialPosition: .region(
                MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(
                        latitudeDelta: 0.01,
                        longitudeDelta: 0.01
                    )
                )
            )
        ) {
            Marker(
                "EcoTouch",
                coordinate: coordinate
            )
        }
        .mapStyle(.standard)
        .allowsHitTesting(false)
    }
}

#Preview {
    MapView(coordinate: CLLocationCoordinate2D(
        latitude: -6.1667,
        longitude: 106.7900)
    )
}
