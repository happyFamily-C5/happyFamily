import SwiftUI

struct EditEventGeneralInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isNameFocused: Bool
    
    @Binding var eventName: String
    @Binding var startDate: Date
    @Binding var endDate: Date
    @Binding var operationalMode: String
    @Binding var activeDays: [Bool]
    @Binding var startTime: Date
    @Binding var endTime: Date
    var onSaveTapped: () -> Void = {}
    
    @State private var activeDateSheet: DateFieldTarget?
    
    private enum DateFieldTarget: Identifiable {
        case start
        case end
        
        var id: Self { self }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            EditEventHeaderView(
                onBackTapped: { dismiss() },
                onSaveTapped: {
                    onSaveTapped()
                    dismiss()
                }
            )
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    TextField("Nama Acara", text: $eventName)
                        .focused($isNameFocused)
                        .textInputAutocapitalization(.words)
                        .font(.system(size: 14))
                        .padding(14)
                        .background(Color(.systemGray6))
                        .cornerRadius(18)
                        .padding(.horizontal, 20)
                    
                    DateTimeRangeCardView(
                        startDate: $startDate,
                        endDate: $endDate
                    )
                    .padding(.horizontal, 20)
                    
                    OperationalScheduleCardView(
                        selectedPreset: $operationalMode,
                        activeDays: $activeDays,
                        startTime: $startTime,
                        endTime: $endTime
                    )
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 18)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Color(.systemBackground))
        .navigationBarHidden(true)
        .sheet(item: $activeDateSheet) { target in
            NavigationStack {
                VStack {
                    DatePicker(
                        target == .start ? "Pilih Tanggal Mulai" : "Pilih Tanggal Selesai",
                        selection: dateBinding(for: target),
                        in: dateRange(for: target),
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.graphical)
                    .padding()
                    Spacer()
                }
                .navigationTitle(target == .start ? "Tanggal Mulai" : "Tanggal Selesai")
                .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.medium])
        }
    }
    
    private func dateBinding(for target: DateFieldTarget) -> Binding<Date> {
        switch target {
        case .start:
            return Binding(
                get: { startDate },
                set: { startDate = min($0, endDate) }
            )
        case .end:
            return Binding(
                get: { endDate },
                set: { endDate = max($0, startDate) }
            )
        }
    }
    
    private func dateRange(for target: DateFieldTarget) -> ClosedRange<Date> {
        switch target {
        case .start:
            return Date.distantPast...endDate
        case .end:
            return startDate...Date.distantFuture
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).year())
    }
}
