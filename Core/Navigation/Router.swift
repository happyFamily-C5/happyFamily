//
//  Router.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 03/09/26.
//

enum AdminsRouter: Hashable {
    case dashboard
    case addEvent
    case openScanner
}

enum DonersRouter: Hashable {
    case donationFlow
    case scan
    case openCamera
    case result
}
