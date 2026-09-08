import SwiftUI
import PhotosUI
import MapKit
import CoreLocation

struct EditEventView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    
    let originalEvent: AdminEvent
    var onSave: (AdminEvent) -> Void
    var onDelete: () -> Void = {}
    var onCancel: () -> Void = {}
    
    @State private var eventName: String
    @State private var eventDescription: String
    @State private var isPhotoPickerPresented = false
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var selectedLocationName: String?
    @State private var selectedLocationAddress: String?
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var operationalMode: String
    @State private var activeDays: [Bool]
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var selectedCategories: Set<String>
    @State private var donationCapacity: Int
    @State private var activeEditor: EditEventEditor?
    @State private var isCapacityPickerOpen = false
    @State private var isShowingCancelSheet = false
    @State private var isShowingCancelSuccess = false
    @State private var shouldCommitLocationOnDismiss = false
    
    private let availableCategories: [String] = [
        "Katun", "Linen", "Rayon", "Wol",
        "Tencel", "Sutra", "Tidak Elastis",
        "Denim", "Tidak berenda",
        "Poliester"
    ]
    private let capacityOptions = Array(stride(from: 10, through: 100, by: 10)) + [200, 300, 400, 500]
    
    private var selectedCriteria: [String] {
        availableCategories.filter { selectedCategories.contains($0) }
    }
    
    private var formattedDateRange: String {
        "\(formattedDate(startDate)) - \(formattedDate(endDate))"
    }
    
    private var formattedTimeInfo: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH.mm"
        return "\(operationalMode) | \(formatter.string(from: startTime)) - \(formatter.string(from: endTime))"
    }
    
    private var criteriaRows: [[String]] {
        stride(from: 0, to: selectedCriteria.count, by: 3).map { startIndex in
            Array(selectedCriteria[startIndex..<min(startIndex + 3, selectedCriteria.count)])
        }
    }
    
    private var updatedEvent: AdminEvent {
        AdminEvent(
            id: originalEvent.id,
            name: eventName,
            description: eventDescription,
            startDate: startDate,
            endDate: endDate,
            locationName: selectedLocationName ?? "",
            locationAddress: selectedLocationAddress ?? "",
            coordinate: selectedCoordinate,
            operationalMode: operationalMode,
            activeDays: activeDays,
            startTime: startTime,
            endTime: endTime,
            donationCriteria: selectedCriteria,
            capacityKg: donationCapacity,
            collectedKg: originalEvent.collectedKg,
            bannerImageData: selectedImageData
        )
    }
    
    private var hasLocationChanges: Bool {
        (selectedLocationName ?? "") != originalEvent.locationName ||
        (selectedLocationAddress ?? "") != originalEvent.locationAddress ||
        !coordinatesMatch(selectedCoordinate, originalEvent.coordinate)
    }
    
    init(
        event: AdminEvent,
        onSave: @escaping (AdminEvent) -> Void,
        onDelete: @escaping () -> Void = {},
        onCancel: @escaping () -> Void = {}
    ) {
        self.originalEvent = event
        self.onSave = onSave
        self.onDelete = onDelete
        self.onCancel = onCancel
        _eventName = State(initialValue: event.name)
        _eventDescription = State(initialValue: event.description)
        _selectedItem = State(initialValue: nil)
        _selectedImageData = State(initialValue: event.bannerImageData)
        _startDate = State(initialValue: event.startDate)
        _endDate = State(initialValue: event.endDate)
        _selectedLocationName = State(initialValue: event.locationName)
        _selectedLocationAddress = State(initialValue: event.locationAddress)
        _selectedCoordinate = State(initialValue: event.coordinate)
        _operationalMode = State(initialValue: event.operationalMode)
        _activeDays = State(initialValue: event.activeDays.count == 7 ? event.activeDays : [true, false, false, false, false, false, true])
        _startTime = State(initialValue: event.startTime)
        _endTime = State(initialValue: event.endTime)
        _selectedCategories = State(initialValue: Set(event.donationCriteria))
        _donationCapacity = State(initialValue: event.capacityKg)
        _activeEditor = State(initialValue: nil)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            EditEventHeaderView(
                onBackTapped: cancelEdit,
                onSaveTapped: saveAndDismiss,
                showsSaveButton: false
            )
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    EditEventBannerSection(
                        selectedImageData: selectedImageData,
                        onTap: { isPhotoPickerPresented = true }
                    )
                    
                    Spacer().frame(height: 12)
                    
                    EditEventInformationSection(
                        eventName: eventName,
                        formattedDateRange: formattedDateRange,
                        formattedTimeInfo: formattedTimeInfo,
                        onTap: { activeEditor = .generalInfo }
                    )
                    
                    Spacer().frame(height: 8)
                    
                    EditEventCapacitySection(
                        donationCapacity: $donationCapacity,
                        isPickerOpen: $isCapacityPickerOpen,
                        capacityOptions: capacityOptions
                    )
                    
                    EditEventCriteriaSection(
                        selectedCriteria: selectedCriteria,
                        criteriaRows: criteriaRows,
                        onTap: { activeEditor = .criteria }
                    )
                    
                    EditEventLocationSection(
                        selectedLocationName: selectedLocationName,
                        selectedLocationAddress: selectedLocationAddress,
                        selectedCoordinate: selectedCoordinate,
                        onTap: {
                            shouldCommitLocationOnDismiss = true
                            router.openMapPicker(
                                location: selectedLocationName,
                                address: selectedLocationAddress,
                                coordinate: selectedCoordinate
                            )
                        }
                    )
                    
                    EditEventDescriptionSection(
                        eventDescription: eventDescription,
                        onTap: { activeEditor = .description }
                    )
                    
                    Spacer().frame(height: 84)
                }
                .padding(.top, 10)
            }
        }
        .background(Color(.systemBackground))
        .safeAreaInset(edge: .bottom) {
            EditEventDeleteButton {
                isShowingCancelSheet = true
            }
        }
        .navigationBarHidden(true)
        .fullScreenCover(item: $activeEditor, onDismiss: commitLocationIfNeeded) { editor in
            editorView(for: editor)
        }
        .sheet(isPresented: $isShowingCancelSheet) {
            CancelEventConfirmationSheet {
                showCancelSuccess()
            }
            .presentationDetents([.height(240)])
            .presentationDragIndicator(.hidden)
        }
        .fullScreenCover(isPresented: $isShowingCancelSuccess) {
            CancelEventSuccessView {
                isShowingCancelSuccess = false
                onDelete()
                dismiss()
            }
        }
        .photosPicker(
            isPresented: $isPhotoPickerPresented,
            selection: $selectedItem,
            matching: .images
        )
        .onChange(of: selectedItem, loadSelectedImage)
        .onChange(of: donationCapacity, commitCapacityChange)
        .onChange(of: startTime, clampEndTime)
        .onChange(of: endTime, clampStartTime)
        .onChange(of: router.mapPickerSession.revision) { _, _ in
            selectedLocationName = router.mapPickerSession.selectedLocation
            selectedLocationAddress = router.mapPickerSession.selectedAddress
            selectedCoordinate = router.mapPickerSession.selectedCoordinate
            commitLocationIfNeeded()
        }
    }
    
    @ViewBuilder
    private func editorView(for editor: EditEventEditor) -> some View {
        switch editor {
        case .generalInfo:
            EditEventGeneralInfoView(
                eventName: $eventName,
                startDate: $startDate,
                endDate: $endDate,
                operationalMode: $operationalMode,
                activeDays: $activeDays,
                startTime: $startTime,
                endTime: $endTime,
                onSaveTapped: commitChanges
            )
        case .criteria:
            EditEventCriteriaView(
                availableCategories: availableCategories,
                selectedCategories: $selectedCategories,
                onSaveTapped: commitChanges
            )
        case .location:
            EmptyView()
        case .description:
            EditEventDescriptionView(
                eventDescription: $eventDescription,
                onSaveTapped: commitChanges
            )
        }
    }
    
    private func cancelEdit() {
        onCancel()
        dismiss()
    }
    
    private func saveAndDismiss() {
        commitChanges()
        dismiss()
    }
    
    private func commitChanges() {
        guard !selectedCategories.isEmpty else { return }
        onSave(updatedEvent)
    }
    
    private func commitLocationIfNeeded() {
        guard shouldCommitLocationOnDismiss else { return }
        shouldCommitLocationOnDismiss = false
        
        if hasLocationChanges {
            commitChanges()
        }
    }
    
    private func showCancelSuccess() {
        isShowingCancelSheet = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isShowingCancelSuccess = true
        }
    }
    
    private func loadSelectedImage(_ oldItem: PhotosPickerItem?, _ newItem: PhotosPickerItem?) {
        Task {
            if let data = try? await newItem?.loadTransferable(type: Data.self) {
                await MainActor.run {
                    selectedImageData = data
                    commitChanges()
                }
            }
        }
    }
    
    private func commitCapacityChange(_ oldCapacity: Int, _ newCapacity: Int) {
        guard oldCapacity != newCapacity else { return }
        commitChanges()
    }
    
    private func clampEndTime(_ oldStart: Date, _ newStart: Date) {
        if endTime < newStart {
            endTime = newStart
        }
    }
    
    private func clampStartTime(_ oldEnd: Date, _ newEnd: Date) {
        if newEnd < startTime {
            startTime = newEnd
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).year())
    }
    
    private func coordinatesMatch(_ lhs: CLLocationCoordinate2D?, _ rhs: CLLocationCoordinate2D?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            return true
        case let (lhs?, rhs?):
            return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
        default:
            return false
        }
    }
}
