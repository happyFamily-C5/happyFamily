//
//  HappyFamilyAppClipsApp.swift
//  HappyFamilyAppClips
//
//  Created by Hendra Irawan on 21/08/26.
//

import SwiftUI

@main
struct HappyFamilyAppClipsApp: App {
    @State private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(router)
        }
    }
}
