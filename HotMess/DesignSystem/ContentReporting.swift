//
//  ContentReporting.swift
//  HotMess
//

import SwiftUI

extension View {
    /// Reporting and blocking from anywhere but chat (which has its own, on
    /// each message): setting `report` asks why, files it with
    /// `reportContent` and, when there's a person behind it, offers to block
    /// them too; setting `block` confirms and blocks. Blocking hides the
    /// person at once (`SafetyStore`).
    func contentReporting(report: Binding<ReportSubject?>, block: Binding<BlockedUser?>) -> some View {
        modifier(ContentReporting(subject: report, blockTarget: block))
    }
}

private struct ContentReporting: ViewModifier {
    @Binding var subject: ReportSubject?
    @Binding var blockTarget: BlockedUser?

    @Environment(AppModel.self) private var model
    /// Reported, with someone behind it who isn't blocked yet.
    @State private var blockOffer: BlockedUser?
    /// Reported, with no one to block.
    @State private var isThanking = false
    @State private var failureMessage: String?

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                subject?.question ?? "",
                isPresented: isPresenting($subject),
                titleVisibility: .visible,
                presenting: subject
            ) { subject in
                ForEach(ChatReportReason.allCases) { reason in
                    Button(reason.title) {
                        Task { await report(subject, reason: reason) }
                    }
                }
                Button(String(localized: "Cancel"), role: .cancel) {}
            } message: { _ in
                Text("Reports are reviewed within 24 hours. Objectionable content will be removed and offending users ejected.")
            }
            .alert(
                String(localized: "Thanks for reporting it"),
                isPresented: isPresenting($blockOffer),
                presenting: blockOffer
            ) { person in
                Button(Self.blockTitle(person), role: .destructive) {
                    Task { await block(person) }
                }
                Button(String(localized: "Not Now"), role: .cancel) {}
            } message: { _ in
                Text("Block them too: they'll be removed from your feed instantly and our team will be notified.")
            }
            .alert(String(localized: "Thanks for reporting it"), isPresented: $isThanking) {
                Button(String(localized: "OK"), role: .cancel) {}
            } message: {
                Text("Our moderation team will review it within 24 hours.")
            }
            .alert(
                Self.blockTitle(blockTarget),
                isPresented: isPresenting($blockTarget),
                presenting: blockTarget
            ) { person in
                Button(String(localized: "Block"), role: .destructive) {
                    Task { await block(person) }
                }
                Button(String(localized: "Cancel"), role: .cancel) {}
            } message: { _ in
                Text("They'll be removed from your feed instantly and our moderation team will be notified.")
            }
            .alert(
                String(localized: "Something went wrong"),
                isPresented: isPresenting($failureMessage),
                presenting: failureMessage
            ) { _ in
                Button(String(localized: "OK"), role: .cancel) {}
            } message: { message in
                Text(message)
            }
    }

    private func report(_ subject: ReportSubject, reason: ChatReportReason) async {
        do {
            try await model.safety.report(subject, reason: reason, block: false)
            if let sender = subject.sender, !model.safety.isBlocked(sender.id) {
                blockOffer = sender
            } else {
                isThanking = true
            }
        } catch {
            failureMessage = String(localized: "The report didn't go through. Please try again.")
        }
    }

    private func block(_ person: BlockedUser) async {
        do {
            try await model.safety.block(person)
        } catch {
            failureMessage = String(localized: "Couldn't block them. Please try again.")
        }
    }

    private static func blockTitle(_ person: BlockedUser?) -> String {
        if let name = person?.name, !name.isEmpty {
            return String(localized: "Block \(name)")
        }
        return String(localized: "Block")
    }

    /// A Bool binding for an optional, for dialogs presenting one.
    private func isPresenting<Value>(_ value: Binding<Value?>) -> Binding<Bool> {
        Binding(
            get: { value.wrappedValue != nil },
            set: { if !$0 { value.wrappedValue = nil } }
        )
    }
}
