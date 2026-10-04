import SwiftUI

@MainActor
struct OperationalScheduleCardView: View {
    @Binding var selectedPreset: String
    @Binding var activeDays: [Bool] // M, S, S, R, K, J, S

    // Jam operasional & State untuk membuka wheel picker
    @Binding var startTime: Date
    @Binding var endTime: Date
    @State private var activeTimePicker: ActiveTimeField?

    enum ActiveTimeField {
        case start, end
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // MARK: - Bagian Hari Operasional

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Hari Operasional")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.primary)

                    Spacer()
                    
                    Menu {
                        Button("Hari Kerja") {
                            selectedPreset = "Hari Kerja"
                            activeDays = [false, true, true, true, true, true, false] // Senin - Jumat
                        }
                        Button("Akhir Pekan") {
                            selectedPreset = "Akhir Pekan"
                            activeDays = [true, false, false, false, false, false, true] // Minggu & Sabtu
                        }
                        Button("Setiap Hari") {
                            selectedPreset = "Setiap Hari"
                            activeDays = [true, true, true, true, true, true, true] // Senin - Minggu
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(selectedPreset)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Divider()

                // Indikator Hari yang bisa diklik manual per lingkaran (M, S, S, R, K, J, S)
                HStack(spacing: 0) {
                    let dayLabels = ["M", "S", "S", "R", "K", "J", "S"]

                    ForEach(0 ..< 7, id: \.self) { index in
                        let isActive = activeDays[index]

                        Button(action: {
                            activeDays[index].toggle()
                            selectedPreset = "Hari Kustom"
                        }) {
                            Text(dayLabels[index])
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(isActive ? .white : .primary)
                                .frame(width: 36, height: 36)
                                .background(isActive ? Color("3-DarkSoftCyan") : Color(.systemBackground))
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color(.systemGray4), lineWidth: isActive ? 0 : 1)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())

                        if index < 6 {
                            Spacer()
                        }
                    }
                }
                .padding(.top, 4)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGray6))
            .cornerRadius(20)

            // MARK: - Bagian Jam Operasional (Gaya Alarm iOS / Wheel Picker)

            VStack(alignment: .leading, spacing: 12) {
                Text("Jam Operasional")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)

                VStack(alignment: .leading, spacing: 0) {
                    // Baris Mulai
                    Button(action: {
                        withAnimation(.snappy) {
                            activeTimePicker = (activeTimePicker == .start) ? nil : .start
                        }
                    }) {
                        HStack {
                            Label("Mulai", systemImage: "clock")
                                .font(.system(size: 15, weight: .regular))
                                .foregroundColor(.primary)

                            Spacer()

                            Text(startTime, format: .dateTime.hour().minute())
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.primary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(Color(.systemBackground))
                                .cornerRadius(8)
                        }
                        .padding(16)
                    }
                    .buttonStyle(PlainButtonStyle())

                    // Wheel Picker untuk Mulai
                    if activeTimePicker == .start {
                        DatePicker(
                            "",
                            selection: startTimeBinding,
                            displayedComponents: [.hourAndMinute]
                        )
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                        .transition(.opacity.combined(with: .move(edge: .top)))

                        Divider()
                            .padding(.horizontal, 16)
                    } else {
                        Divider()
                            .padding(.horizontal, 16)
                    }

                    // Baris Selesai
                    Button(action: {
                        withAnimation(.snappy) {
                            activeTimePicker = (activeTimePicker == .end) ? nil : .end
                        }
                    }) {
                        HStack {
                            Label("Selesai", systemImage: "clock.fill")
                                .font(.system(size: 15, weight: .regular))
                                .foregroundColor(.primary)

                            Spacer()

                            Text(endTime, format: .dateTime.hour().minute())
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.primary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(Color(.systemBackground))
                                .cornerRadius(8)
                        }
                        .padding(16)
                    }
                    .buttonStyle(PlainButtonStyle())

                    // Wheel Picker untuk Selesai
                    if activeTimePicker == .end {
                        DatePicker(
                            "",
                            selection: endTimeBinding,
                            displayedComponents: [.hourAndMinute]
                        )
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(20)
            }
        }
        // Padding horizontal dihapus dari sini agar mengikuti lebar penuh dari parent container Step 2
    }

    private var startTimeBinding: Binding<Date> {
        Binding(
            get: { startTime },
            set: { newValue in
                startTime = newValue
                if endTime < newValue {
                    endTime = newValue
                }
            }
        )
    }

    private var endTimeBinding: Binding<Date> {
        Binding(
            get: { endTime },
            set: { newValue in
                endTime = newValue
                if newValue < startTime {
                    startTime = newValue
                }
            }
        )
    }
}

// MARK: - Preview

#Preview(traits: .sizeThatFitsLayout) {
    @Previewable @State var preset = "Akhir Pekan"
    @Previewable @State var days = [true, false, false, false, false, false, true]
    @Previewable @State var start = Calendar.current.date(from: DateComponents(hour: 8, minute: 0)) ?? Date()
    @Previewable @State var end = Calendar.current.date(from: DateComponents(hour: 16, minute: 0)) ?? Date()

    return OperationalScheduleCardView(
        selectedPreset: $preset,
        activeDays: $days,
        startTime: $start,
        endTime: $end
    )
    .padding()
}
