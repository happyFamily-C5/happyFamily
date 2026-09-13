import SwiftUI

struct CompletedEventCard: View {
    let title: String
    let type: String
    let startDate: Date
    let endDate: Date
    let collectedWeight: Double
    let targetWeight: Double

    private var goalText: String {
        if collectedWeight >= targetWeight {
            "\(Int(targetWeight))Kg Goal Reached"
        } else {
            "\(Int(collectedWeight))Kg of \(Int(targetWeight))Kg Collected"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "building.2.fill")
                    .font(.system(size: 34))
                    .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(type)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                AdminBadge()
                    .offset(x: 8, y: -12)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(
                    "\(startDate.formatted(date: .long, time: .omitted)) - \(endDate.formatted(date: .long, time: .omitted))"
                )
                .font(.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

                Text(goalText)
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .padding(.leading, 60)
        }
        .foregroundStyle(AppColor.textColor)
        .padding(16)
        .padding(.top, 4)
        .background(Color("5-LightSoftCyan"))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(
            color: .black.opacity(0.12),
            radius: 8,
            y: 4
        )
    }
}

#Preview("Completed Event Card") {
    let calendar = Calendar.current

    let startDate = calendar.date(
        from: DateComponents(
            year: 2026,
            month: 9,
            day: 6
        )
    )!

    let endDate = calendar.date(
        from: DateComponents(
            year: 2026,
            month: 12,
            day: 9
        )
    )!

    ZStack {
        AppColor.baseColor
            .ignoresSafeArea()

        CompletedEventCard(
            title: "September Office Collection",
            type: "Office Donation",
            startDate: startDate,
            endDate: endDate,
            collectedWeight: 60,
            targetWeight: 60
        )
        .padding(.horizontal, 16)
    }
}
