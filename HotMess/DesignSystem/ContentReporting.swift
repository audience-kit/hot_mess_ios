//
//  ContentReporting.swift
//  HotMess
//

import SwiftUI

extension View {
    /// Reporting and blocking from anywhere but chat (which has its own, on
    /// each message): setting `report` opens `ReportSheet`, which asks why and,
    /// when there's a person behind it, offers to block them too, then files it
    /// with `reportContent`; setting `block` confirms and blocks. Blocking hides the
    /// person at once (`SafetyStore`).
    func contentReporting(report: Binding<ReportSubject?>, block: Binding<BlockedUser?>) -> some View {
        modifier(ContentReporting(subject: report, blockTarget: block))
    }
}

private struct ContentReporting: ViewModifier {
    @Binding var subject: ReportSubject?
    @Binding var blockTarget: BlockedUser?

    @Environment(AppModel.self) private var model
    /// Reported; thanked once the report sheet has gone.
    @State private var didReport = false
    @State private var isThanking = false
    @State private var failureMessage: String?

    func body(content: Content) -> some View {
        content
            .sheet(item: $subject, onDismiss: thankIfReported) { subject in
                ReportSheet(question: subject.question, blockable: blockable(subject)) { reason, block in
                    try await model.safety.report(subject, reason: reason, block: block)
                    didReport = true
                }
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

    /// Who the sheet offers to block too: the person behind it, unless they're already blocked.
    private func blockable(_ subject: ReportSubject) -> BlockedUser? {
        subject.sender.flatMap { model.safety.isBlocked($0.id) ? nil : $0 }
    }

    private func thankIfReported() {
        if didReport {
            didReport = false
            isThanking = true
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
