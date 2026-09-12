//
//  DonationInstructionPage.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 08/09/26.
//

import SwiftUI

struct DonationInstructionPage: View {
    @Environment(\.presentationMode) private var dismiss
    @Environment(AppRouter.self) var router

    @State private var agreed = true
    @State private var currentPage = 0

    let slides: [GuideSlide] = [
        //        GuideSlide(
//            id: 0,
//            illustration: "donationGuide1",
//            title: "Pilah dan pisahkan pakaian",
//            description: "pisahkan pakaian yang masih layak digunakan dari pakaian atau tekstil yang suda tidak layak digunakan."
//        ),
        GuideSlide(
            id: 1,
            illustration: "donationGuide2",
            title: "Kemas dalam tempat yang bersih",
            description: "Gunakan tas, kantong, atau kardus yang bersih dan cukup kuat untuk membawa seluruh pakaianmu."
        ),
        GuideSlide(
            id: 2,
            illustration: "donationGuide3",
            title: "Tempelkan label pada setiap kemasan",
            description: "Tempelkan kode QR yang telah diunduh atau tuliskan Kode booking yang diberikan di setiap kemasan."
        ),
        GuideSlide(
            id: 3,
            illustration: "donationGuide4",
            title: "Antarkan ke titik kumpul",
            description: "Bawa pakaian yang sudah dikemas ke drop point pilihanmu sesuai lokasi dan waktu yang tersedia."
        ),
    ]

    init() {
        UIPageControl.appearance().currentPageIndicatorTintColor = .black
        UIPageControl.appearance().pageIndicatorTintColor = .gray.withAlphaComponent(0.3)
        UIPageControl.appearance().backgroundColor = .white
    }

    var body: some View {
        TabView(selection: $currentPage) {
            ForEach(slides) { slide in
                VStack(spacing: 16) {
                    Image(slide.illustration)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 225)

                    VStack(spacing: 8) {
                        Text(slide.title)
                            .font(.title2).bold()
                            .multilineTextAlignment(.center)

                        Text(slide.description)
                            .font(.callout)
                            .multilineTextAlignment(.center)
                    }
                    if slide.id == slides.last?.id {
                        Button {
                            dismiss.wrappedValue.dismiss()
                            router.popToRoot()
                        } label: {
                            Text("Selesai")
                                .font(.body).bold()
                                .foregroundStyle(Color.white)
                                .padding(.vertical, 16)
                                .frame(maxWidth: .infinity)
                                .background(
                                    AppColor.primaryCyan,
                                    in: RoundedRectangle(cornerRadius: 99)
                                )
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .tabViewStyle(PageTabViewStyle())
        .indexViewStyle(.page(backgroundDisplayMode: .never))
    }
}

#Preview {
    DonationInstructionPage()
        .environment(AppRouter())
}
