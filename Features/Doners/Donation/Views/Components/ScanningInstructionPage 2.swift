//
//  DonationInstructionPage.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 08/09/26.
//

import SwiftUI

struct ScanningInstructionPage: View {
    @Environment(\.presentationMode) private var dismiss
    @Environment(AppRouter.self) var router
    
    
    @State private var agreed = true
    @State private var currentPage = 0
    
    let slides: [ScanningGuideSlide] = [
        ScanningGuideSlide(
            id: 0,
            illustration: "scan1",
            title: "Kenapa kamu harus memindai setiap pakaian ?",
            description: "Memindai setiap pakaian yang akan kamu donasikan memudahkan kami agar bisa mendaur ulang pakaian yang kamu donasikan."
        ),
        ScanningGuideSlide(
            id: 1,
            illustration: "scan2",
            title: "Bentangkan pakaian",
            description: "Letakkan pakaian di lantai , meja atau gantung pada hanger. Hindari lipatan baju yang menumpuk."
        ),
        ScanningGuideSlide(
            id: 2,
            illustration: "scan3",
            title: "Foto di tempat yang terang",
            description: "Foto pakaian di tempat dengan kondisi pencahayaan yang cukup terang agar kondisi pakaian terdeteksi secara akurat"
        ),
        ScanningGuideSlide(
            id: 3,
            illustration: "scan4",
            title: "Satu Pakaian per Foto",
            description: "Pindai satu per satu pakaian yang akan kamu donasikan agar kami bisa memproses donasi kamu dengan lebih mudah"
        )
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
                            Button{
                                router.push(to: .openCamera)
                                dismiss.wrappedValue.dismiss()
                            }label: {
                                Text("Ambil Gambar")
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
    ScanningInstructionPage()
        .environment(AppRouter())
}
