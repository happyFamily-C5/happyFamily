import SwiftUI

struct ProfileEventHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    
    let events: [AdminEvent]
    
    private var displayedEvents: [AdminEvent] {
        events.isEmpty ? [ProfileHistoryDummyData.completedEvent] : events
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ProfileBackBar(
                onBackTapped: { dismiss() }
            )
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Riwayat Acara")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 20)
                    
                    if displayedEvents.isEmpty {
                        ProfileEmptyHistoryView(
                            systemImage: "calendar.badge.exclamationmark",
                            title: "Belum Ada Riwayat Acara",
                            message: "Acara yang selesai akan tampil\ndi halaman ini"
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.top, 170)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(displayedEvents) { event in
                                ProfileEventHistoryRow(event: event)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.top, 18)
                .padding(.bottom, 32)
            }
        }
        .background(Color(.systemBackground))
        .navigationBarHidden(true)
    }
}

struct ProfileDonationHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    
    let donations: [ProfileDonation]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ProfileBackBar(
                onBackTapped: { dismiss() }
            )
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Riwayat\nPendonasi")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 20)
                    
                    if donations.isEmpty {
                        ProfileEmptyHistoryView(
                            systemImage: "list.clipboard",
                            title: "Belum Ada Riwayat Pendonasi",
                            message: "Donatur yang telah memberikan donasi\nakan tampil di halaman ini"
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.top, 170)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(donations) { donation in
                                ProfileDonationHistoryRow(donation: donation)
                                
                                Divider()
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.top, 18)
                .padding(.bottom, 32)
            }
        }
        .background(Color(.systemBackground))
        .navigationBarHidden(true)
    }
}

private struct ProfileEventHistoryRow: View {
    let event: AdminEvent
    
    var body: some View {
        HStack(spacing: 12) {
            event.bannerImage
                .resizable()
                .scaledToFill()
                .frame(width: 78, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(event.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                Text(event.formattedDateRange)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
    }
}

private struct ProfileDonationHistoryRow: View {
    let donation: ProfileDonation
    
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(donation.donorName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
                
                Text(donation.relativeTime)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(donation.weightText)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(Color("3-DarkSoftCyan"))
        }
        .padding(.vertical, 10)
    }
}

private struct ProfileEmptyHistoryView: View {
    let systemImage: String
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 58, weight: .regular))
                .foregroundColor(Color("3-DarkSoftCyan"))
            
            VStack(spacing: 5) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text(message)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}
