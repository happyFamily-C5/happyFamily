import SwiftUI

struct EditEventCriteriaView: View {
    @Environment(\.dismiss) private var dismiss

    let availableCategories: [String]
    @Binding var selectedCategories: Set<String>
    var onSaveTapped: () -> Void = {}

    @State private var isShowingEmptyWarning = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            EditEventHeaderView(
                onBackTapped: { dismiss() },
                onSaveTapped: saveCriteria
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Edit Kriteria\nDonasi")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.primary)

                        Text("Pilih kategori pakaian yang akan diterima sebagai donasi.")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 20)

                    AdminFlowLayout(spacing: 10) {
                        ForEach(availableCategories, id: \.self) { category in
                            let isSelected = selectedCategories.contains(category)

                            DonationTagChip(title: category, isSelected: isSelected) {
                                if isSelected {
                                    selectedCategories.remove(category)
                                } else {
                                    selectedCategories.insert(category)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    if selectedCategories.isEmpty || isShowingEmptyWarning {
                        Text("Pilih minimal 1 kriteria donasi sebelum menyimpan.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(red: 0.78, green: 0.12, blue: 0.12))
                            .padding(.horizontal, 20)
                    }
                }
                .padding(.vertical, 18)
            }
        }
        .background(Color(.systemBackground))
        .navigationBarHidden(true)
    }

    private func saveCriteria() {
        guard !selectedCategories.isEmpty else {
            isShowingEmptyWarning = true
            return
        }

        onSaveTapped()
        dismiss()
    }
}
