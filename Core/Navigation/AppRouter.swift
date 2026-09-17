//
//  AppRouter.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 03/09/26.
//

import CoreLocation
import Observation
import SwiftUI

@Observable
final class MapPickerSession {
    var selectedLocation: String?
    var selectedAddress: String?
    var selectedCoordinate: CLLocationCoordinate2D?
    var revision = 0

    func begin(
        location: String?,
        address: String?,
        coordinate: CLLocationCoordinate2D?
    ) {
        selectedLocation = location
        selectedAddress = address
        selectedCoordinate = coordinate
    }

    func confirm() {
        revision += 1
    }
}

@Observable
final class AppRouter {
    var adminPath: [AdminsRouter] = []
    var donersPath: [DonersRouter] = []
    var mapPath: [MapPickerRouter] = []
    let mapPickerSession = MapPickerSession()
    var selectedClothingItem: ClothingItem?
    var currentStep: Int = 1
    /// Shared donation flow state. App-scope so the event detail CTA and
    /// the flow's step views observe the same instance.
    let donation = DonationViewModel()
    var adminProfile = AdminProfile.defaultProfile
    var donorProfile = DonorProfile.defaultProfile
    /// Set by the root coordinator: donor-profile logout must end the whole
    /// session, not just pop the navigation stack.
    var onLogout: (() -> Void)?
    /// Set by the root coordinator so deletion passes through the authenticated
    /// backend and clears the app session afterward.
    var onDeleteAccount: (() async throws -> Void)?
    /// Backend-backed admin profile save (uploads the logo, updates the
    /// workspace, and requests the email change when needed).
    var onSaveAdminProfile: ((AdminProfile) async throws -> Void)?

    func push(to destination: AdminsRouter) {
        adminPath.append(destination)
    }

    func push(to destination: DonersRouter) {
        donersPath.append(destination)
    }

    func pop() {
        if !donersPath.isEmpty {
            donersPath.removeLast()
        }
    }

    func openClothDetail(for item: ClothingItem) {
        selectedClothingItem = item
        donersPath.append(.clothDetail)
    }

    func openMapPicker(
        location: String?,
        address: String?,
        coordinate: CLLocationCoordinate2D?
    ) {
        mapPickerSession.begin(
            location: location,
            address: address,
            coordinate: coordinate
        )
        mapPath.append(.picker)
    }

    func openDonersMapPicker(
        location: String?,
        address: String?,
        coordinate: CLLocationCoordinate2D?
    ) {
        mapPickerSession.begin(
            location: location,
            address: address,
            coordinate: coordinate
        )
        donersPath.append(.mapPicker)
    }

    func finishMapPicker() {
        mapPickerSession.confirm()
        mapPath.removeLast()
    }

    func popToRoot() {
        if !adminPath.isEmpty {
            adminPath.removeAll()
        }

        if !donersPath.isEmpty {
            donersPath.removeAll()
        }

        if !mapPath.isEmpty {
            mapPath.removeAll()
        }

        currentStep = 1
    }

    func nextStep() {
        currentStep += 1
    }
}


extension View {
    func mapPickerRouter(_ router: AppRouter) -> some View {
        self.navigationDestination(for: MapPickerRouter.self) { destination in
            switch destination {
            case .picker:
                MapPickerRouteView(session: router.mapPickerSession) {
                    router.finishMapPicker()
                }
            }
        }
    }

    func adminsRouter(_ router: AppRouter) -> some View {
        self.navigationDestination(for: AdminsRouter.self) { destination in
            switch destination {
            case .dashboard:
                DashboardView()
            case .addEvent:
                EmptyView()
            case .openScanner:
                QRScannerView()
            case .profile:
                ProfileView(
                    profile: Bindable(router).adminProfile,
                    onLogout: { router.onLogout?() },
                    onDeleteAccount: router.onDeleteAccount,
                    onSaveProfile: router.onSaveAdminProfile
                )
            }
        }
    }

    func donersRouter(_ router: AppRouter) -> some View {
        self.navigationDestination(for: DonersRouter.self) { destination in
            switch destination {
            case .donationFlow:
                DonationFlowView()
            case .scan:
                ClothsView { router.nextStep() }
            case .openCamera:
                ScanView()
            case .mapPicker:
                MapPickerRouteView(session: router.mapPickerSession) {
                    router.mapPickerSession.confirm()
                    router.donersPath.removeLast()
                }
            case .clothDetail:
                if let item = router.selectedClothingItem {
                    ClothDetailView(item: item)
                }
            case let .eventDetail(eventId):
                SelectedEventDetailView(
                    model: DonorEventDetailModel(
                        eventId: eventId,
                        accountClient: BackendDependencies.accountClientOrDefault(),
                        backendBaseURL: BackendDependencies.backendBaseURL()
                    )
                )
            case .myBookings:
                MyBookingsView()
            case let .bookingDetail(bookingId):
                DonorBookingDetailView(bookingId: bookingId)
            case .history:
                DonorHistoryView()
            case .profile:
                DonorProfileView(
                    profile: Bindable(router).donorProfile,
                    onLogout: { router.onLogout?() },
                    onDeleteAccount: router.onDeleteAccount
                )
            case .trackingHistory:
                TrackingHistoryView()
            case .forYouPage:
                ForYouView()
            case .trendPage:
                TrendingView()
            }
        }
    }
}
