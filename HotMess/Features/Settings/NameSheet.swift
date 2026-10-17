//
//  NameSheet.swift
//  HotMess
//

import SwiftUI

/// "Add your name", on Me for an account without one: Sign in with Apple
/// gives the name only the first time someone authorizes the app, so an
/// account made later (say, after deleting one) starts unnamed.
struct NameSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var isSaving = false
    @State private var failed = false
    @FocusState private var isFocused: Bool

    private var first: String { firstName.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var last: String { lastName.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "First name"), text: $firstName)
                        .textContentType(.givenName)
                        .submitLabel(.next)
                        .focused($isFocused)
                        .accessibilityIdentifier("name.first")
                    TextField(String(localized: "Last name"), text: $lastName)
                        .textContentType(.familyName)
                        .submitLabel(.done)
                        .onSubmit { Task { await save() } }
                        .accessibilityIdentifier("name.last")
                } footer: {
                    Text("Your friends see your full name. Everyone else sees your first name and last initial.")
                }
            }
            .navigationTitle(String(localized: "Your Name"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Save")) { Task { await save() } }
                        .fontWeight(.semibold)
                        .disabled(first.isEmpty || isSaving)
                        .accessibilityIdentifier("name.save")
                }
            }
            .alert(String(localized: "Couldn't save your name"), isPresented: $failed) {
                Button(String(localized: "OK"), role: .cancel) {}
            } message: {
                Text("Please try again, or try a different name.")
            }
            .onAppear { isFocused = true }
        }
    }

    private func save() async {
        guard !first.isEmpty, !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try await model.session.updateName(firstName: first, lastName: last.isEmpty ? nil : last)
            dismiss()
        } catch {
            failed = true
        }
    }
}
