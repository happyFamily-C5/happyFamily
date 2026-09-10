//
//  AdminEventStore.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 04/09/26.
//

import Observation
import Foundation

@Observable
final class AdminEventStore {
    var events: [AdminEvent] = []
    var selectedEventID: UUID?

    var selectedEventIndex: Int? {
        guard let selectedEventID else { return nil }

        return events.firstIndex {
            $0.id == selectedEventID
        }
    }

    func acceptDonation(weight: Double) {
        guard let index = selectedEventIndex else { return }

        events[index].collectedKg += weight
    }
}
