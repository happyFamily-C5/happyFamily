import SwiftUI

@MainActor
struct DateTimeRangeCardView: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    @State private var showStartPicker = false
    @State private var showEndPicker = false
    
    private enum DateTarget {
        case start
        case end
    }
    
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
                    dateRow(
                        title: "Mulai",
                        date: startDate,
                        isPickerPresented: $showStartPicker,
                        target: .start
                    )
                    
                    Divider()
                    
                    dateRow(
                        title: "Selesai",
                        date: endDate,
                        isPickerPresented: $showEndPicker,
                        target: .end
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading) // Memastikan card melebar penuh
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(20)
        // Padding horizontal dihapus dari sini agar mengikut parent container Step 2
    }
    
    private func dateRow(
        title: String,
        date: Date,
        isPickerPresented: Binding<Bool>,
        target: DateTarget
    ) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(.primary)
            
            Spacer()
            
            Button {
                isPickerPresented.wrappedValue = true
            } label: {
                Text(formattedDate(date))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white)
                    .cornerRadius(24)
            }
            .buttonStyle(.plain)
            .popover(
                isPresented: isPickerPresented,
                attachmentAnchor: .rect(.bounds),
                arrowEdge: .top
            ) {
                datePicker(for: target)
            }
        }
    }
    
    private func datePicker(for target: DateTarget) -> some View {
        DatePicker(
            target == .start ? "Pilih Tanggal Mulai" : "Pilih Tanggal Selesai",
            selection: binding(for: target),
            in: dateRange(for: target),
            displayedComponents: [.date]
        )
        .datePickerStyle(.graphical)
        .padding()
        .frame(width: 340)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .presentationCompactAdaptation(.popover)
    }
    
    private func binding(for target: DateTarget) -> Binding<Date> {
        switch target {
        case .start:
            return Binding(
                get: { startDate },
                set: {
                    startDate = $0
                    endDate = max(endDate, $0)
                }
            )
        case .end:
            return Binding(
                get: { endDate },
                set: { endDate = max($0, startDate) }
            )
        }
    }
    
    private func dateRange(for target: DateTarget) -> ClosedRange<Date> {
        switch target {
        case .start:
            let today = Calendar.current.startOfDay(for: Date())
            return today...Date.distantFuture
        case .end:
            return startDate...Date.distantFuture
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).year())
    }
}


// MARK: - Preview
#Preview(traits: .sizeThatFitsLayout) {
    DateTimeRangeCardView(
        startDate: .constant(Date()),
        endDate: .constant(Calendar.current.date(byAdding: .day, value: 6, to: Date()) ?? Date())
    )
    .padding()
}
