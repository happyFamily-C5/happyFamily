//
//  Event.swift
//  happyFamily
//
//  Created by Hendra Irawan on 27/08/26.
//


import Foundation

struct Event: Identifiable {
    let id = UUID()
    
    let title: String
    let organizer: String
    let bannerImageName: String
}
