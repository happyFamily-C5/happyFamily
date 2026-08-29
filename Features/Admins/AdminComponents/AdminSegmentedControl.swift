import SwiftUI

enum AdminSegment: String, CaseIterable, Identifiable {
    case history
    case draft

    var id: Self { self }

    var title: String {
        switch self {
        case .history:
            return "History"
        case .draft:
            return "Draft"
        }
    }
}

struct AdminSegmentedControl: View {
    @Binding var selection: AdminSegment

    var body: some View {
        Picker("Admin section", selection: $selection) {
            ForEach(AdminSegment.allCases) { segment in
                Text(segment.title)
                    .tag(segment)
            }
        }
        .pickerStyle(.segmented)
        .tint(Color("2-BoldDarkSoftCyan"))
        .foregroundStyle(AppColor.textColor)
    }
}

#Preview {
    @Previewable @State var selection: AdminSegment = .history

    ZStack {
        AppColor.baseColor
            .ignoresSafeArea()

        AdminSegmentedControl(selection: $selection)
            .padding()
    }
}
