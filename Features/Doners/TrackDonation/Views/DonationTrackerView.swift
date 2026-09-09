//
//  DonationTracker.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 09/09/26.
//

import SwiftUI

struct DonationTrackerView: View {
    @Environment(\.dismiss) private var dismiss
    
    let status: DonationTrackingStatus
    
    @State private var showCancelSheet = false
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack {
                ScrollView {
                    VStack(spacing: 32) {
                        bookingCard
                        
                        statusCard
                    }
                }
                .scrollIndicators(.hidden)
                
                if status == .readyToDeliver {
                    Button {
                        showCancelSheet = true
                    } label: {
                        Text("Batalkan Booking")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                Color.red.opacity(0.75),
                                in: Capsule()
                            )
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .navigationTitle("Lacak Donasi")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showCancelSheet) {
            CancelBookingSheet {
                showCancelSheet = false
                dismiss()
            }
            .background(Color.white)
            .presentationDetents([.height(350)])
            .presentationDragIndicator(.visible)
        }
    }
}

private extension DonationTrackerView {
    
    var bookingCard: some View {
        ZStack(alignment: .topTrailing) {
            Image("qrFrame")
                .resizable()
                .scaledToFit()
            
            VStack(spacing: 24) {
                Image(uiImage: generateQRCode(from: "SS-76329"))
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 214)
                
                
                Text("Tunjukkan Kode QR ke Pengelola")
                    .font(.footnote)
                
                Spacer()
                
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Nomor Booking")
                            .font(.body)
                        
                        Text("SS-76329")
                            .font(.largeTitle).bold()
                    }
                    
                    Spacer()
                    
                    Button {
                        UIPasteboard.general.string = "SS-76329"
                    } label: {
                        Text("Salin")
                            .font(.body).bold()
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                AppColor.primaryCyan,
                                in: Capsule()
                            )
                    }
                }
            }
            .padding(20)
            .padding(.top, 16)
            
            Button {
                // Share QR
            } label: {
                Image(systemName: "square.and.arrow.up")
//                    .font(.system(size: 16))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
                    .background(.white)
                    .clipShape(Circle())
                    .shadow(
                        color: .black.opacity(0.12),
                        radius: 6
                    )
            }
            .buttonStyle(.plain)
            .padding(10)
        }
        .frame(width: 320)
    }
    
    var statusCard: some View {
        VStack(alignment: .leading, spacing: 24) {
            
            HStack {
                Text("Status Pelacakan")
                    .font(.headline)
                
                Spacer()
                
                if status == .completed {
                    Text("Selesai")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            Color.green,
                            in: Capsule()
                        )
                }
            }
            .padding(.top, 20)
            .padding(.horizontal, 20)
            
            timeline
            
        }
        .padding(16)
        .background(.white)
        .clipShape(
            RoundedRectangle(cornerRadius: 36)
        )
    }
    
    var timeline: some View {
        VStack(spacing: 16) {
            
            timelineRow(
                date: "9 Sept\n04.00 pm",
                title: "Segera Antarkan",
                description: "Donasi sudah hampir kami terima di drop point",
                state: stateFor(.readyToDeliver),
                isLast: false
            )
            
            timelineRow(
                date: "01.00 pm",
                title: "Diterima",
                description: "Donasimu sudah kami terima di drop point",
                state: stateFor(.received),
                isLast: false
            )
            
            timelineRow(
                date: "10.00 am",
                title: "Diproses",
                description: "Kami sedang mengolah donasi pakaian kamu menjadi sesuatu yang berguna",
                state: stateFor(.processed),
                isLast: false
            )
            
            timelineRow(
                date: "8 Sept\n08.00 am",
                title: "Telah di Daur Ulang",
                description: "Pengolahan pakaian selesai. Terima kasih sudah berperan menjaga bumi!",
                state: stateFor(.completed),
                isLast: true
            )
        }
        .padding(.bottom, 20)
        .padding(.horizontal, 20)
    }
    
    enum TimelineState {
        case active
        case inactive
        case completed
    }
    
    func stateFor(
        _ item: DonationTrackingStatus
    ) -> TimelineState {
        
        switch status {
            
        case .readyToDeliver:
            return item == .readyToDeliver
            ? .active
            : .inactive
            
        case .received:
            if item == .received {
                return .active
            }
            
            return item == .readyToDeliver
            ? .completed
            : .inactive
            
        case .processed:
            if item == .processed {
                return .active
            }
            
            if item == .readyToDeliver || item == .received {
                return .completed
            }
            
            return .inactive
            
        case .completed:
            return .completed
        }
    }
    
    func timelineRow(
        date: String,
        title: String,
        description: String,
        state: TimelineState,
        isLast: Bool
    ) -> some View {

        HStack(alignment: .top, spacing: 12) {

            // MARK: - Date

            Text(date)
                .font(.caption2)
                .foregroundStyle(
                    state == .active
                        ? .primary
                        : .secondary
                )
                .frame(
                    width: 62,
                    alignment: .leading
                )

            // MARK: - Timeline
            VStack(spacing: 0) {

                Circle()
                    .fill(
                        state == .active
                            ? AppColor.primaryCyan
                            : Color.gray.opacity(0.45)
                    )
                    .frame(width: 14, height: 14)
                    .overlay {
                        if state == .active {
                            Circle()
                                .stroke(
                                    AppColor.primaryCyan.opacity(0.25),
                                    lineWidth: 5
                                )
                        }
                    }

                if !isLast {
                    Path { path in
                        path.move(
                            to: CGPoint(x: 0.75, y: 0)
                        )

                        path.addLine(
                            to: CGPoint(x: 0.75, y: 80)
                        )
                    }
                    .stroke(
                        Color.gray.opacity(0.35),
                        style: StrokeStyle(
                            lineWidth: 1.5,
                            dash: [3, 4]
                        )
                    )
                    .frame(
                        width: 1.5,
                        height: 65
                    )
                }
            }
            .frame(width: 14)

            // MARK: - Content

            VStack(alignment: .leading, spacing: 4) {

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(
                        state == .active
                            ? AppColor.primaryCyan
                            : .secondary
                    )

                Text(description)
                    .font(.caption)
                    .foregroundStyle(
                        state == .active
                            ? .primary
                            : .secondary
                    )
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
            }
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
        }
    }

    var timelineLine: some View {
        Path { path in
            path.move(
                to: CGPoint(x: 7, y: 0)
            )

            path.addLine(
                to: CGPoint(x: 7, y: 100)
            )
        }
        .stroke(
            Color.gray.opacity(0.35),
            style: StrokeStyle(
                lineWidth: 1.5,
                dash: [3, 4]
            )
        )
        .frame(
            width: 14,
            height: 52
        )
    }
}




#Preview {
    NavigationStack {
        DonationTrackerView(status: .readyToDeliver)
    }
}
