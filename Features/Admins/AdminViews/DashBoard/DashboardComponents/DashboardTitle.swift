import SwiftUI

struct DashboardTitleView: View {
    let hasOngoingEvent: Bool
    
    // Logika AttributedString untuk judul saat ada event aktif dengan format dua baris ("Acara Anda yang\nsedang berlangsung")
    private var ongoingEventTitle: AttributedString {
        var title = AttributedString("Acara Anda yang\nsedang berlangsung")
        
        if let range = title.range(of: "Acara Anda") {
            title[range].font = .system(size: 30, weight: .bold)
        }
        if let range = title.range(of: "yang") {
            title[range].font = .system(size: 30, weight: .regular)
        }
        if let range = title.range(of: "sedang") {
            title[range].font = .system(size: 30, weight: .regular)
        }
        if let range = title.range(of: "berlangsung") {
            title[range].font = .system(size: 30, weight: .bold)
        }
        
        return title
    }
    
    // Logika AttributedString untuk judul saat kosong ("Tambahkan lebih\nbanyak Event")
    private var emptyEventTitle: AttributedString {
        var title = AttributedString("Tambahkan lebih\nbanyak Event")
        
        if let range = title.range(of: "Tambahkan") {
            title[range].font = .system(size: 30, weight: .bold)
        }
        if let range = title.range(of: "lebih") {
            title[range].font = .system(size: 30, weight: .regular)
        }
        if let range = title.range(of: "banyak") {
            title[range].font = .system(size: 30, weight: .regular)
        }
        if let range = title.range(of: "Event") {
            title[range].font = .system(size: 30, weight: .bold)
        }
        
        return title
    }
    
    var body: some View {
        Group {
            if hasOngoingEvent {
                Text(ongoingEventTitle)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 16)
            } else {
                Text(emptyEventTitle)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 16)
            }
        }
    }
}

// MARK: - Preview
#Preview(traits: .sizeThatFitsLayout) {
    VStack(alignment: .leading, spacing: 30) {
        VStack(alignment: .leading, spacing: 4) {
            Text("Preview State Kosong:")
                .font(.caption)
                .foregroundColor(.secondary)
            DashboardTitleView(hasOngoingEvent: false)
        }
        
        VStack(alignment: .leading, spacing: 4) {
            Text("Preview State Ada Event Aktif:")
                .font(.caption)
                .foregroundColor(.secondary)
            DashboardTitleView(hasOngoingEvent: true)
        }
    }
    .padding()
}
