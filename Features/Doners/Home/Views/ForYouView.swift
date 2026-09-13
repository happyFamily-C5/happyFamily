//
//  ForYouView.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 09/09/26.
//

import SwiftUI

/// "Untuk Kamu" page: the recommendation rail of `account:dashboard`.
/// Tapping a card opens the backend `account:event_detail` flow.
struct ForYouView: View {
    @Environment(AppRouter.self) private var router
    @State private var model = DonorHomeModel(
        accountClient: BackendDependencies.accountClientOrDefault(),
        backendBaseURL: BackendDependencies.backendBaseURL()
    )

    var body: some View {
        Group {
            if model.isLoading, model.dashboard == nil {
                VStack {
                    ProgressView("Memuat acara…")
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = model.errorMessage, model.dashboard == nil {
                VStack(spacing: 12) {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Coba lagi") {
                        Task { await model.load() }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    let events = model.dashboard?.recommendedEvents ?? []
                    if events.isEmpty {
                        Text("Belum ada rekomendasi acara.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 170)
                    } else {
                        VStack(spacing: 32) {
                            ForEach(events) { event in
                                Button {
                                    router.push(to: .eventDetail(event.id))
                                } label: {
                                    ForYouCard(
                                        title: event.name,
                                        startDate: Self.dateText(event.startAt),
                                        endDate: Self.dateText(event.endAt),
                                        location: event.locationName ?? "Lokasi menyusul",
                                        bannerURL: model.bannerURL(for: event)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 18)
                        .padding(.bottom, 32)
                    }
                }
            }
        }
        .navigationTitle("Untuk Kamu")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
    }

    private static func dateText(_ date: Date?) -> String {
        guard let date else { return "-" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "id_ID")
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        ForYouView()
            .environment(AppRouter())
    }
}
