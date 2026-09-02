import SwiftUI

@MainActor
struct DateTimeRangeCardView: View {
    let startDateString: String
    let endDateString: String
    var onStartTap: () -> Void
    var onEndTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 16) {
                
                VStack(spacing: 4) {
                    Circle()
                        .fill(Color(.systemBackground))
                        .overlay(Circle().stroke(Color.primary, lineWidth: 2))
                        .frame(width: 8, height: 8)
                    
                    // Garis Putus-putus Vertikal
                    Path { path in
                        path.move(to: CGPoint(x: 1, y: 0))
                        path.addLine(to: CGPoint(x: 1, y: 18))
                    }
                    .stroke(Color.secondary, style: StrokeStyle(lineWidth: 2, dash: [3, 3]))
                    .frame(width: 2, height: 18)
                    
                    // Titik Selesai (Hitam penuh)
                    Circle()
                        .fill(Color.primary)
                        .frame(width: 8, height: 8)
                }
                .frame(width: 12)
                
                // Baris Tanggal Mulai dan Selesai
                VStack(alignment: .leading, spacing: 12) {
                    Button(action: onStartTap) {
                        dateRow(title: "Mulai", dateString: startDateString)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Divider()
                    
                    Button(action: onEndTap) {
                        dateRow(title: "Selesai", dateString: endDateString)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading) // Memastikan card melebar penuh
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(20)
        // Padding horizontal dihapus dari sini agar mengikut parent container Step 2
    }
    
    private func dateRow(title: String, dateString: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(dateString)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.systemBackground))
                .cornerRadius(8)
        }
    }
}

// MARK: - Preview
#Preview(traits: .sizeThatFitsLayout) {
    DateTimeRangeCardView(
        startDateString: "1 Aug, 2026",
        endDateString: "7 Aug, 2026",
        onStartTap: { print("Tanggal mulai diklik") },
        onEndTap: { print("Tanggal selesai diklik") }
    )
    .padding()
}
