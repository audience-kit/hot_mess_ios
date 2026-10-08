//
//  ReportProblemScreen.swift
//  HotMess
//

import SwiftUI
import UIKit

/// "Report a Problem": what went wrong, in the person's words, sent to the
/// AudienceKit API with the app's version and, if they agree, the last few
/// errors the app saw. Reachable from Me, and from a failed sign-in.
struct ReportProblemScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var details = ""
    @State private var email = ""
    @State private var includeDiagnostics = true
    @State private var isSending = false
    @State private var didSend = false
    @State private var failure: String?

    var body: some View {
        Form {
            Section {
                TextEditor(text: $details)
                    .frame(minHeight: 160)
                    .accessibilityIdentifier("report.description")
            } header: {
                Text("What went wrong?")
            } footer: {
                Text("Say what you were doing and what you expected to happen.")
            }

            if !model.session.isSignedIn {
                Section {
                    TextField(String(localized: "Email (optional)"), text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("report.email")
                } footer: {
                    Text("So we can get back to you.")
                }
            }

            Section {
                Toggle(String(localized: "Include diagnostics"), isOn: $includeDiagnostics)
            } footer: {
                Text("Your app version, device and the last few errors Hot Mess saw. Never your messages or where you are.")
            }

            if let failure {
                Section {
                    Text(failure)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(String(localized: "Report a Problem"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if isSending {
                    ProgressView()
                } else {
                    Button(String(localized: "Send")) {
                        Task { await send() }
                    }
                    .disabled(trimmedDetails.isEmpty)
                    .accessibilityIdentifier("report.send")
                }
            }
        }
        .alert(String(localized: "Thanks for letting us know"), isPresented: $didSend) {
            Button(String(localized: "OK")) { dismiss() }
        } message: {
            Text("Your report is on its way to the Hot Mess team.")
        }
    }

    private var trimmedDetails: String {
        details.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func send() async {
        isSending = true
        failure = nil
        defer { isSending = false }

        let signedIn = model.session.isSignedIn
        do {
            try await model.api.reportProblem(request(signedIn: signedIn), signedIn: signedIn)
            didSend = true
        } catch {
            failure = String(localized: "Couldn't send your report. Check your connection and try again.")
        }
    }

    private func request(signedIn: Bool) -> BugReportRequest {
        let configuration = model.configuration
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        return BugReportRequest(
            description: trimmedDetails,
            email: trimmedEmail.isEmpty ? nil : trimmedEmail,
            screen: signedIn ? model.selectedTab.title : "Sign in",
            version: configuration.version,
            build: String(configuration.build),
            osVersion: "iOS \(UIDevice.current.systemVersion)",
            device: DeviceInfo.model,
            host: configuration.audienceHost,
            diagnostics: includeDiagnostics ? BugReportRequest.Diagnostics(
                signedIn: signedIn,
                environment: configuration.environment.rawValue,
                locale: model.location.locale?.name,
                recentErrors: ErrorReporter.shared.recent
            ) : nil
        )
    }
}
