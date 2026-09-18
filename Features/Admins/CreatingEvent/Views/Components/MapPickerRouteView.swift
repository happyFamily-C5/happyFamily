import CoreLocation
import SwiftUI

struct MapPickerRouteView: View {
    let session: MapPickerSession
    let onFinish: () -> Void

    var body: some View {
        MainMapPickerView(
            selectedLocation: Binding(
                get: { session.selectedLocation },
                set: { session.selectedLocation = $0 }
            ),
            selectedAddress: Binding(
                get: { session.selectedAddress },
                set: { session.selectedAddress = $0 }
            ),
            selectedCoordinate: Binding(
                get: { session.selectedCoordinate },
                set: { session.selectedCoordinate = $0 }
            ),
            onConfirm: onFinish
        )
    }
}
