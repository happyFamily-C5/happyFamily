import SwiftUI

struct DonorEventHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    
    let events: [AdminEvent]
    
    private var displayedEvents: [AdminEvent] {
        events.isEmpty ? [ProfileHistoryDummyData.completedEvent] : events
    }
    
    private var activeEvents: [AdminEvent] {
        displayedEvents.filter { $0.endDate >= Date() }
    }
    
    private var pastEvents: [AdminEvent] {
        displayedEvents.filter { $0.endDate < Date() }
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
                            message: "Acara yang kamu ikuti akan tampil\ndi halaman ini"
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.top, 170)
                    } else {
                        if !activeEvents.isEmpty {
                            DonorEventSection(title: "Acara Aktif", events: activeEvents)
                        }
                        
                        if !pastEvents.isEmpty {
                            DonorEventSection(title: "Acara Sebelumnya", events: pastEvents)
                        }
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

private struct DonorEventSection: View {
    let title: String
    let events: [AdminEvent]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.primary)
                .padding(.horizontal, 20)
            
            VStack(spacing: 12) {
                ForEach(events) { event in
                    ProfileEventHistoryRow(event: event)
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

struct DonorDonationHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    
    let donations: [DonorDonation]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ProfileBackBar(
                onBackTapped: { dismiss() }
            )
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Riwayat Donasi")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 20)
                    
                    if donations.isEmpty {
                        ProfileEmptyHistoryView(
                            systemImage: "list.clipboard",
                            title: "Belum Ada Riwayat Donasi",
                            message: "Donasi yang telah kamu berikan\nakan tampil di halaman ini"
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.top, 170)
                    } else {
                        VStack(spacing: 18) {
                            ForEach(donations) { donation in
                                DonorDonationRow(donation: donation)
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

private struct DonorDonationRow: View {
    let donation: DonorDonation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(donation.eventName)
                        .font(.body).bold()
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    Text(donation.dateRangeText)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(donation.weightText)
                    .font(.title2).bold()
                    .foregroundColor(AppColor.primaryCyan)
                
            }
            Divider()
        }
    }
}

#Preview {
    DonorDonationHistoryView(donations: DonorDonation.sampleData)
}
