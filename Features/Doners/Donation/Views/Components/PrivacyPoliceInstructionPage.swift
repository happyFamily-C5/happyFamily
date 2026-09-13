//
//  PrivacyPoliceInstructionPage.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 08/09/26.
//

import SwiftUI

struct PrivacyPoliceInstructionPage: View {
    let onAccepted: () -> Void

    let slides: [OnboardingSlide] = [
        OnboardingSlide(id: 0, illustration: "carousel1", description: "Siap memberi pakaianmu kehidupan kedua?"),
        OnboardingSlide(
            id: 1,
            illustration: "carousel2",
            description: "Pastikan pakaian yang kamu donasikan bersih, kering, dan aman untuk diproses"
        ),
        OnboardingSlide(
            id: 2,
            illustration: "carousel3",
            description: "Pakaian telah terpisah dari semua aksesoris yang menempel (kancing, zipper, dll)"
        ),
        OnboardingSlide(id: 3, illustration: "carousel4", description: "Pastikan pakaian sesuai dengan kriteria bahan yang diminta"),
    ]

    init(onAccepted: @escaping () -> Void = {}) {
        self.onAccepted = onAccepted
        UIPageControl.appearance().currentPageIndicatorTintColor = .black
        UIPageControl.appearance().pageIndicatorTintColor = .gray.withAlphaComponent(0.3)
        UIPageControl.appearance().backgroundColor = .white
    }

    var body: some View {
        TabView {
            ForEach(slides) { slide in
                VStack(spacing: 24) {
                    Image(slide.illustration)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 225)

                    Text(slide.description)
                        .font(.title2).bold()
                        .multilineTextAlignment(.center)
                }
            }

            TermsPage(onAccepted: onAccepted)
        }
        .padding(.horizontal, 20)
        .tabViewStyle(PageTabViewStyle())
        .indexViewStyle(.page(backgroundDisplayMode: .never))
    }
}

#Preview {
    PrivacyPoliceInstructionPage()
}
