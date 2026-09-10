//
//  AppRouter.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 03/09/26.
//

import Observation
import SwiftUI
import CoreLocation

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
    var adminProfile = AdminProfile.defaultProfile
    var donorProfile = DonorProfile.defaultProfile
    var adminEvents: [AdminEvent] = []
    var donorEvents: [AdminEvent] = []

    func push(to destination:AdminsRouter) {
        adminPath.append(destination)
    }
    
    func push(to destination:DonersRouter) {
        donersPath.append(destination)
    }
    
    func pop(){
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
    
    func popToRoot(){
        if !adminPath.isEmpty{
            adminPath.removeAll()
        }
        
        if !donersPath.isEmpty{
            donersPath.removeAll()
        }

        if !mapPath.isEmpty {
            mapPath.removeAll()
        }
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
                    events: router.adminEvents,
                    profile: Bindable(router).adminProfile
                )
            }
        }
    }
    
    func donersRouter(_ router: AppRouter) -> some View {
        self.navigationDestination(for: DonersRouter.self) { destination in
            switch destination {
            case  .donationFlow:
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
                } else {
                    EmptyView()
                }
            case .profile:
                DonorProfileView(
                    events: router.donorEvents,
                    profile: Bindable(router).donorProfile
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
