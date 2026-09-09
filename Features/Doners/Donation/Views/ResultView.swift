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
    @State private var isShareSheetPresented = false
    
    let onNext: () -> Void
    @State var showNotification = false
    @State var showGuide = false
    
    var body: some View {
        ZStack {
            VStack(spacing: 16) {
                
                // MARK: - Badge Icon
                VStack(spacing: 8) {
                    ZStack {
                        Image(systemName: "seal.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(AppColor.primaryCyan)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    Text("Booking Confirmed!")
                        .font(.title3).bold()
                    
                    Text("Unduh label berikut, kemudian cetak dan tempelkan pada paket kardus sebelum dikirim.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                // MARK: - Label Card
                labelCard
                Spacer()
                
                // MARK: - Buttons
                VStack(spacing: 8) {
                    if labelFile != nil {
                        Button {
                            isShareSheetPresented = true
                        } label: {
                            buttonLabel("Unduh Label")
                        }
                        .buttonStyle(.plain)
                        .background(AppColor.primaryCyan)
                        .clipShape(Capsule())
                    } else {
                        buttonLabel("Menyiapkan label…")
                            .background(Color.gray.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 99))
                    }
                    
                    Button{
                        showGuide = true
                    } label: {
                        Text("Donasikan Pakaian")
                            .font(.body).bold()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .padding(.horizontal, 16)
                            .background(
                                Color(#colorLiteral(red: 0.4240652323, green: 0.424192071, blue: 0.4281041622, alpha: 1)).opacity(0.2),
                                in: RoundedRectangle(cornerRadius: 99)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
            }
        }
        .overlay(alignment: .top) {
            if showNotification {
                DownloadedLabelNotification()
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showGuide, content: {
            DonationInstructionPage()
                .background(Color.white)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        })
        .sheet(isPresented: $isShareSheetPresented) {
            if let labelFile {
                ActivityShareSheet(item: labelFile) { completed in
                    isShareSheetPresented = false

                    guard completed else { return }
                    withAnimation(.easeInOut) {
                        showNotification = true
                    }

                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(2.5))
                        withAnimation(.easeInOut) {
                            showNotification = false
                        }
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .task {
            print("ISI QR:")
            print(donationVM.qrContent)
            renderLabel()
        }
    }
    
    private var labelCard: LabelCard {
        LabelCard(
            senderName: donationVM.name,
            receiverName: "EcoTouch Indonesia",
            receiverPhone: "0878-8271-0777",
            receiverAddress: "Jl. Arjuna Utara No.14D, RT.1/RW.1, Tj. Duren Sel., Kec. Grogol petamburan, Kota Jakarta Barat, Daerah Khusus Ibukota Jakarta 11470",
            qrContent: donationVM.qrContent
        )
    }
    
    private func buttonLabel(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundColor(labelFile == nil ? .primary : .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
    }
    
    @MainActor
    private func renderLabel() {
        guard labelFile == nil else { return }
        
        let renderer = ImageRenderer(
            content: labelCard
                .frame(width: 320)
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
    ResultView(onNext: {})
        .environment(DonationViewModel())
        .environment(AppRouter())
}
