//
//  MapView.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 26/08/26.
//

import MapKit
import SwiftUI

struct MapView: View {
    let coordinate: CLLocationCoordinate2D
    let locationName: String

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
                locationName,
                coordinate: coordinate
            )
        }
        .mapStyle(.standard)
        //        .allowsHitTesting(false)
        .onTapGesture {
            openInMaps()
        }
    }

    private func openInMaps() {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let mapItem = MKMapItem(location: location, address: nil)
        mapItem.name = locationName
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving,
        ])
    }
}

#Preview {
    MapView(
        coordinate: CLLocationCoordinate2D(
            latitude: -6.1667,
            longitude: 106.7900
        ),
        locationName: "EcoTouch Office"
    )
}
