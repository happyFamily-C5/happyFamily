import Foundation
//  Router.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 03/09/26.
//

enum AdminsRouter: Hashable {
    case dashboard
    case addEvent
}

enum MapPickerRouter: Hashable {
    case picker
}

enum DonersRouter: Hashable {
    case donationFlow
    case scan
    case openCamera
    case mapPicker
    case clothDetail
    case eventDetail(UUID)
    case myBookings
    case bookingDetail(UUID)
    case history
}
