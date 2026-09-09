//
//  DonationViewModel.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 27/08/26.
//

import SwiftUI
import CoreImage.CIFilterBuiltins

enum ShippingMethod: String, CaseIterable, Identifiable {
    case direct = "Antar Langsung"
    case ojekOnline = "Ojek Online"
    case expedition = "Ekspedisi"
    
    var id: String { rawValue }
    
    var description: String {
        switch self {
        case .direct:
            return "Kamu membawa langsung paketnya ke lokasi drop-point"
        case .ojekOnline:
            return "Kamu pesan ojek, biar driver yang antar paketnya ke lokasi drop-point"
        case .expedition:
            return "Kamu bawa paketnya ke ekspedisi terdekat, biar kurir yang antar paketnya ke lokasi drop-point"
        }
    }
}


@MainActor
@Observable
final class DonationViewModel {
    var name: String = ""
    var phone: String = ""
    
    var agreedToTerms: Bool = false
    var selectedShippingMethod: ShippingMethod?
    var clothingItems: [ClothingItem] = [
//        ClothingItem(image: UIImage(named: "Image 3") ?? UIImage(), isPassed: true)
    ]

    private(set) var resolvedEvent: PublicEventDTO?
    private(set) var legal: PublicLegalDTO?
    private(set) var booking: CreateBookingData?
    private(set) var isResolving = false
    private(set) var isCreatingBooking = false
    var errorMessage: String?

    private let client: any PublicBackendServing
    private let backendBaseURL: URL?
    private var invocationToken: String?
    private var lastInvocationURL: URL?
    private var bookingRequest: CreateBookingRequest?
    private var bookingIdempotencyKey: String?

    init(
        client: any PublicBackendServing = FullAppBackendDependencies.client(),
        backendBaseURL: URL? = FullAppBackendDependencies.baseURL()
    ) {
        self.client = client
        self.backendBaseURL = backendBaseURL
    }

    var displayBookingID: String {
        booking?.bookingId ?? ""
    }

    var bannerURL: URL? {
        guard let backendBaseURL, let path = resolvedEvent?.bannerObjectPath else { return nil }
        return backendBaseURL
            .appending(path: "storage/v1/object/public/event-banners", directoryHint: .isDirectory)
            .appending(path: path)
    }

    var qrContent: String {
        """
        Booking ID: \(displayBookingID)
        Nama: \(name)
        No. Telp: \(phone)
        """
    }
    
    // MARK: - Validasi tiap step
    var canProceedFromPersonalInfo: Bool {
        !name.isEmpty && !phone.isEmpty && agreedToTerms
    }
    
    var canProceedFromCapture: Bool {
        !clothingItems.isEmpty
    }
    
    var canProceedFromReview: Bool {
        clothingItems.contains { $0.isPassed }
    }

    var canProceedFromShipping: Bool {
        selectedShippingMethod != nil && !isCreatingBooking
    }

    func loadDevelopmentInvocationIfPresent() async {
        guard
            lastInvocationURL == nil,
            let rawURL = ProcessInfo.processInfo.environment["_XCAppClipURL"],
            let url = URL(string: rawURL)
        else { return }
        await handleInvocation(url)
    }

    func handleInvocation(_ url: URL) async {
        lastInvocationURL = url
        isResolving = true
        errorMessage = nil
        defer { isResolving = false }
        do {
            let invocation = try InvocationParser.parse(url)
            if invocation.token != invocationToken {
                resetDonationState()
            }
            invocationToken = invocation.token
            let response = try await client.resolveEvent(invocationToken: invocation.token)
            resolvedEvent = response.event
            legal = response.legal
        } catch is CancellationError {
            return
        } catch {
            resolvedEvent = nil
            legal = nil
            errorMessage = error.localizedDescription
        }
    }

    func retryResolve() async {
        guard let lastInvocationURL else { return }
        await handleInvocation(lastInvocationURL)
    }

    func createBooking() async -> Bool {
        guard let invocationToken, let legal, let event = resolvedEvent else {
            errorMessage = BackendError.invalidInvocationURL.localizedDescription
            return false
        }
        guard event.availability.acceptsBookings else {
            errorMessage = BackendError.api(
                code: "EVENT_UNAVAILABLE",
                retryable: false,
                fieldErrors: [:],
                requestId: nil
            ).localizedDescription
            return false
        }
        guard let selectedShippingMethod else { return false }

        let passedItems = clothingItems.filter(\.isPassed)
        guard !passedItems.isEmpty else { return false }

        if bookingRequest == nil {
            bookingRequest = CreateBookingRequest(
                invocationToken: invocationToken,
                donorName: name,
                phone: phone,
                estimatedWeightGrams: Int64(passedItems.count * 500),
                itemCount: passedItems.count,
                items: passedItems.enumerated().map { index, item in
                    BookingItemRequest(
                        ordinal: index + 1,
                        passed: true,
                        scannerModelVersion: item.scannerModelVersion,
                        metadata: item.metadata
                    )
                },
                shippingMethod: selectedShippingMethod.code,
                scanModelVersion: passedItems.map(\.scannerModelVersion).joined(separator: "+"),
                termsVersion: legal.termsVersion,
                privacyVersion: legal.privacyVersion
            )
            bookingIdempotencyKey = UUID().uuidString.lowercased()
        }
        guard let bookingRequest, let bookingIdempotencyKey else { return false }

        isCreatingBooking = true
        errorMessage = nil
        defer { isCreatingBooking = false }
        do {
            booking = try await client.createBooking(
                bookingRequest,
                idempotencyKey: bookingIdempotencyKey
            )
            return true
        } catch is CancellationError {
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func resetDonationState() {
        name = ""
        phone = ""
        agreedToTerms = false
        selectedShippingMethod = nil
        clothingItems = []
        booking = nil
        bookingRequest = nil
        bookingIdempotencyKey = nil
    }
}

private extension ShippingMethod {
    var code: ShippingMethodCode {
        switch self {
        case .direct: .direct
        case .ojekOnline: .ojekOnline
        case .expedition: .expedition
        }
    }
}

func generateQRCode(from string: String) -> UIImage {
    let context = CIContext()
    let filter = CIFilter.qrCodeGenerator()
    filter.correctionLevel = "H"
    filter.message = Data(string.utf8)
    
    if let outputImage = filter.outputImage {
        let scaled = outputImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        if let cgImage = context.createCGImage(scaled, from: scaled.extent) {
            return UIImage(cgImage: cgImage)
        }
    }
    return UIImage(systemName: "xmark") ?? UIImage()
}
