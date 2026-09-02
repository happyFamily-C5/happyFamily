//
//  ResultView.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 30/08/26.
//

import SwiftUI

struct ResultView: View {
    @Environment(DonationViewModel.self) var donationVM
    @Environment(\.displayScale) private var displayScale

    /// The rendered label, written to a temporary file so the share sheet can
    /// hand it to Files / AirDrop / Print. An App Clip cannot write to Photos,
    /// so the share sheet is the only route out of the clip for this image.
    @State private var labelFile: URL?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.75, green: 0.85, blue: 0.78), Color.white],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 40)

                // MARK: - Badge Icon
                ZStack {
                    Image(systemName: "seal.fill")
                        .font(.system(size: 60))
                        .foregroundColor(Color(red: 0.35, green: 0.5, blue: 0.45))

                    Image(systemName: "checkmark")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                }

                Text("Booking Confirmed!")
                    .font(.title3).bold()
                    .padding(.top, 20)

                Text("Unduh label berikut, kemudian cetak dan tempelkan pada paket kardus sebelum dikirim.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 8)

                // MARK: - Label Card
                labelCard
                Spacer()

                // MARK: - Buttons
                VStack(spacing: 12) {
                    if let labelFile {
                        ShareLink(item: labelFile) {
                            buttonLabel("Unduh Label")
                        }
                        .background(AppColor.primaryCyan)
                        .clipShape(Capsule())
                    } else {
                        buttonLabel("Menyiapkan label…")
                            .background(Color.gray.opacity(0.3))
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }
        }
        .navigationBarBackButtonHidden(true)
        .task { renderLabel() }
    }

    private var labelCard: LabelCard {
        LabelCard(
            senderName: donationVM.name,
            receiverName: "EcoTouch Indonesia",
            receiverPhone: "0878-8271-0777",
            receiverAddress: "Jl. Arjuna Utara No.14D, RT.1/RW.1, Tj. Duren Sel., Kec. Grogol petamburan, Kota Jakarta Barat, Daerah Khusus Ibukota Jakarta 11470",
            qrContent: donationVM.bookingID
        )
    }

    private func buttonLabel(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundColor(labelFile == nil ? .primary : .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
    }

    @MainActor
    private func renderLabel() {
        guard labelFile == nil else { return }

        let renderer = ImageRenderer(
            content: labelCard
                .frame(width: 400)
                .background(Color.white)
        )
        renderer.scale = displayScale

        guard let image = renderer.uiImage, let png = image.pngData() else { return }

        let url = URL.temporaryDirectory
            .appending(path: "Label-\(donationVM.displayBookingID).png")
        do {
            try png.write(to: url, options: .atomic)
            labelFile = url
        } catch {
            assertionFailure("Gagal menulis label ke \(url.path): \(error)")
        }
    }
}

#Preview {
    ResultView()
        .environment(DonationViewModel())
}
