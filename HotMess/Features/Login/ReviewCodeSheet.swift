//
//  ReviewCodeSheet.swift
//  HotMess
//

import SwiftUI

/// "Have an App Review code?": where Apple's App Review team enters the code
/// from the review notes, which signs in the designated reviewer account. The
/// login screen only offers it while the API says App Review sign-in is on.
struct ReviewCodeSheet: View {
    /// Called with the trimmed code once the sheet has closed.
    var onSubmit: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @FocusState private var isFocused: Bool

    private var trimmedCode: String {
        code.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "Review code"), text: $code)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.oneTimeCode)
                        .submitLabel(.go)
                        .focused($isFocused)
                        .onSubmit(submit)
                        .accessibilityIdentifier("reviewCode.field")
                } footer: {
                    Text("For Apple's App Review team. Enter the code from the App Review notes in App Store Connect.")
                }
            }
            .navigationTitle(String(localized: "App Review"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Sign In"), action: submit)
                        .fontWeight(.semibold)
                        .disabled(trimmedCode.isEmpty)
                        .accessibilityIdentifier("reviewCode.submit")
                }
            }
            .onAppear { isFocused = true }
        }
    }

    private func submit() {
        let value = trimmedCode
        guard !value.isEmpty else { return }
        dismiss()
        onSubmit(value)
    }
}

#Preview {
    ReviewCodeSheet { _ in }
}
