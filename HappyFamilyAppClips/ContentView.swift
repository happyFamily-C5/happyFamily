//
//  ContentView.swift
//  HappyFamilyAppClips
//
//  Created by Hendra Irawan on 21/08/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack {
            AppColor.baseColor
                .ignoresSafeArea()

            VStack(spacing: 12) {
                Image(systemName: "globe")
                    .imageScale(.large)
                    .foregroundStyle(AppColor.accentColor)
                Text("Hello, world! This is AppClip")
                    .font(.title2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ContentView()
}
