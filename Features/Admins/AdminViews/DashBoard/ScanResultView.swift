import SwiftUI

/// Reception is deliberately driven from a resolved server booking. The raw
/// QR token never becomes a booking id, PII cache, or a local booking
/// mutation in the app.
struct ScanResultView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var router
    @ObservedObject var scanner: QRScannerViewModel
    @State private var booking: ResolvedQRBooking?
    @State private var isResolving = true
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showWheel = false
    @State private var showDonationSuccess = false
    @State private var showDonationReject = false

    var body: some View {
        Group {
            if let booking {
                bookingDetail(booking)
            } else if isResolving {
                ProgressView("Memverifikasi QR…")
            } else {
                ContentUnavailableView(
                    "QR tidak dapat diproses",
                    systemImage: "qrcode.viewfinder",
                    description: Text(errorMessage ?? "Coba scan lagi.")
                )
            }
        }
        .task { await resolveBooking() }
        .alert("Penerimaan gagal", isPresented: Binding(
            get: { errorMessage != nil && booking != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Terjadi kesalahan.")
        }
    }

    @ViewBuilder
    private func bookingDetail(_ booking: ResolvedQRBooking) -> some View {
        VStack {
            VStack(spacing: 28) {
                VStack(spacing: 4) {
                    Text("Nomor Booking").font(.body)
                    Text(booking.publicBookingId).font(.title).bold()
                }
                HStack(spacing: 16) {
                    Image("Image 2").resizable().scaledToFit().frame(height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(booking.eventSnapshot.name).font(.title3).bold()
                        Text(booking.eventSnapshot.receiverName).font(.headline)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)

                List {
                    Section {
                        receptionRow("Nama", booking.donorName)
                        receptionRow("No Telepon", booking.donorPhone)
                    }
                    Section {
                        Button { withAnimation(.snappy) { showWheel.toggle() } } label: {
                            HStack {
                                Image(systemName: "shippingbox.fill")
                                Text("Berat Aktual")
                                Spacer()
                                Text("\(scanner.actualWeight, specifier: "%.1f") kg")
                                    .foregroundStyle(.secondary)
                                Image(systemName: "chevron.up.chevron.down").foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        if showWheel {
                            Picker("Berat Aktual", selection: $scanner.actualWeight) {
                                ForEach(scanner.actualWeightOpt, id: \.self) { weight in
                                    Text("\(weight, specifier: "%.1f") kg").tag(weight)
                                }
                            }
                            .frame(height: 100).pickerStyle(.wheel)
                        }
                    }
                }
                .listStyle(.insetGrouped).scrollDisabled(true).scrollContentBackground(.hidden)
            }
            .padding(.top, 24)
            Spacer()
            Button(isSubmitting ? "Memproses…" : "Terima") {
                Task { await decide(.accepted, booking: booking) }
            }
            .buttonStyle(ReceptionButtonStyle(color: AppColor.primaryCyan))
            .disabled(isSubmitting)
            Button(isSubmitting ? "Memproses…" : "Tolak") {
                Task { await decide(.rejected, booking: booking) }
            }
            .buttonStyle(ReceptionButtonStyle(color: Color(red: 0.78, green: 0.12, blue: 0.12)))
            .disabled(isSubmitting)
        }
        .navigationTitle("Detail Donasi")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showDonationSuccess) {
            AcceptDonationView(onReturnHome: returnHome)
        }
        .navigationDestination(isPresented: $showDonationReject) {
            RejectedDonationView(onReturnHome: returnHome)
        }
    }

    private func receptionRow(_ title: String, _ value: String) -> some View {
        HStack { Text(title); Spacer(); Text(value).bold() }
    }

    private func resolveBooking() async {
        guard booking == nil, let token = scanner.result, !token.isEmpty else {
            isResolving = false
            return
        }
        isResolving = true
        defer { isResolving = false }
        do {
            booking = try await BackendDependencies.receptionRepository().resolveQR(token: token)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func decide(_ decision: ReceptionDecisionCode, booking: ResolvedQRBooking) async {
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let grams = decision == .accepted ? Int64((scanner.actualWeight * 1000).rounded()) : 0
            let key = "reception-\(booking.bookingId.uuidString)-\(decision.rawValue)-\(grams)"
            _ = try await BackendDependencies.receptionRepository().decide(ReceptionDecisionInput(
                bookingId: booking.bookingId,
                decision: decision,
                actualWeightGrams: grams,
                condition: .good,
                rejectionReason: nil,
                rejectionNote: nil,
                idempotencyKey: key,
                requestId: UUID()
            ))
            if decision == .accepted { showDonationSuccess = true } else { showDonationReject = true }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func returnHome() {
        dismiss()
        router.popToRoot()
    }
}

private struct ReceptionButtonStyle: ButtonStyle {
    let color: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white).font(.body.bold()).frame(maxWidth: .infinity)
            .padding(16).background(color, in: RoundedRectangle(cornerRadius: 60))
            .opacity(configuration.isPressed ? 0.7 : 1)
            .padding(.horizontal, 20)
    }
}

#Preview {
    NavigationStack { ScanResultView(scanner: QRScannerViewModel()) }
        .environment(AppRouter())
}
