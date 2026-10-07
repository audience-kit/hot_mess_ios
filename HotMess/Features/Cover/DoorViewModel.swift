//
//  DoorViewModel.swift
//  HotMess
//

import Foundation
import Observation
import UIKit

/// Door mode: scans passes at one venue's door and keeps tonight's counts.
@MainActor
@Observable
final class DoorViewModel {
    let venues: [DoorVenue]
    private(set) var selectedVenueID: UUID
    /// Tonight's counts per venue.
    private(set) var counts: [UUID: DoorCounts] = [:]
    /// The last scan's answer, shown full screen for a moment.
    private(set) var result: ScanResult?
    private(set) var isChecking = false
    var errorMessage: String?

    /// How long a result stays up.
    static let resultDuration: Duration = .seconds(2)
    /// The same pass is ignored for this long after a scan, so the camera
    /// doesn't read it again while it's still in front of it.
    static let repeatInterval: TimeInterval = 30

    private let api: HotMessAPI
    private var lastPass: String?
    private var lastScanAt = Date.distantPast
    private var dismissTask: Task<Void, Never>?

    init(api: HotMessAPI, venues: [DoorVenue]) {
        self.api = api
        self.venues = venues
        selectedVenueID = venues.first?.id ?? UUID()

        for venue in venues {
            if let door = venue.door { counts[venue.id] = door }
        }
    }

    var selectedVenue: DoorVenue? {
        venues.first { $0.id == selectedVenueID }
    }

    var selectedCounts: DoorCounts? {
        counts[selectedVenueID]
    }

    func select(_ venue: DoorVenue) {
        guard venue.id != selectedVenueID else { return }

        selectedVenueID = venue.id
        lastPass = nil
        Task { await refreshCounts() }
    }

    /// A code the camera read. Ignored while a scan is being checked or shown,
    /// and for a while after the same pass was scanned.
    func scanned(_ code: String) {
        guard !isChecking, result == nil else { return }

        let pass = Self.passKey(for: code)
        let now = Date()
        if pass == lastPass, now.timeIntervalSince(lastScanAt) < Self.repeatInterval { return }

        lastPass = pass
        lastScanAt = now
        Task { await check(code) }
    }

    func dismissResult() {
        dismissTask?.cancel()
        result = nil
    }

    func refreshCounts() async {
        let venueID = selectedVenueID

        do {
            if let door = try await api.doorCounts(venueID: venueID) {
                counts[venueID] = door
            }
        } catch {
            // The counts are a convenience; scanning works without them.
        }
    }

    private func check(_ code: String) async {
        isChecking = true
        defer { isChecking = false }

        do {
            show(try await api.scanAdmission(venueID: selectedVenueID, code: code))
            await refreshCounts()
        } catch {
            // Let the same pass be tried again once the connection is back.
            lastPass = nil
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func show(_ scan: ScanResult) {
        result = scan

        let feedback: UINotificationFeedbackGenerator.FeedbackType = switch scan.outcome {
        case .admit: .success
        case .reEntry: .warning
        default: .error
        }
        UINotificationFeedbackGenerator().notificationOccurred(feedback)

        dismissTask?.cancel()
        dismissTask = Task {
            try? await Task.sleep(for: Self.resultDuration)
            guard !Task.isCancelled else { return }
            result = nil
        }
    }

    /// The admission a pass code is for, so a new code for the same pass (a
    /// new window) still counts as a repeat. Anything else is its own key.
    nonisolated static func passKey(for code: String) -> String {
        let parts = code.split(separator: ".")
        guard parts.count == 4, parts[0] == Substring(CoverPass.prefix) else { return code }
        return String(parts[1])
    }
}
