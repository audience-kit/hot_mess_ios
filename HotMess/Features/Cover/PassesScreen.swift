//
//  PassesScreen.swift
//  HotMess
//

import Observation
import SwiftUI

@MainActor
@Observable
final class PassesViewModel {
    private(set) var state: LoadState<[Admission]> = .idle

    private let api: HotMessAPI

    init(api: HotMessAPI) {
        self.api = api
    }

    func load() async {
        if state.value == nil { state = .loading }

        do {
            state = .loaded(try await api.admissions())
        } catch is CancellationError {
        } catch {
            state = LoadState(catching: error)
        }
    }
}

/// The user's cover passes, newest first, from the Me tab.
struct PassesScreen: View {
    @Environment(AppModel.self) private var model
    @State private var viewModel: PassesViewModel?

    var body: some View {
        LoadStateView(state: viewModel?.state ?? .loading, retry: reload) { admissions in
            if admissions.isEmpty {
                ContentUnavailableView {
                    Label(String(localized: "No Passes Yet"), systemImage: "ticket")
                } description: {
                    Text("Pay cover from a venue's page and your pass shows up here.")
                }
            } else {
                List(admissions) { admission in
                    Button {
                        model.checkout.show(admission)
                    } label: {
                        PassRow(admission: admission)
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.insetGrouped)
                .refreshable { await viewModel?.load() }
            }
        }
        .navigationTitle(String(localized: "Passes"))
        .task(id: model.checkout.revision) {
            ensureViewModel()
            await viewModel?.load()
        }
    }

    private func ensureViewModel() {
        if viewModel == nil {
            viewModel = PassesViewModel(api: model.api)
        }
    }

    private func reload() {
        Task {
            ensureViewModel()
            await viewModel?.load()
        }
    }
}

struct PassRow: View {
    let admission: Admission

    var body: some View {
        HStack(spacing: 12) {
            RemoteImage(url: admission.venuePhotoURL)
                .frame(width: 48, height: 48)
                .clipShape(.rect(cornerRadius: HotMessRadius.lg))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(admission.venueName)
                        .font(.hotMess(.headline, semibold: true))
                        .lineLimit(1)

                    if admission.isCoatCheck {
                        Image(systemName: "hanger")
                            .font(.caption)
                            .foregroundStyle(Color.hotMessAccent)
                    }
                }

                Text(subtitleText)
                    .font(.hotMess(.subheadline))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Text(statusBadgeText)
                .font(.hotMess(.caption, semibold: true))
                .foregroundStyle(admission.isPaid ? Color.hotMessAccent : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    admission.isPaid ? Color.hotMessAccentSoft : Color(.tertiarySystemFill),
                    in: .capsule
                )
        }
        .padding(.vertical, 2)
        .contentShape(.rect)
    }

    private var statusBadgeText: String {
        if admission.isCoatCheck && admission.isPaid {
            if admission.scanCount >= 2 { return String(localized: "Claimed") }
            if admission.scanCount == 1 { return String(localized: "Checked In") }
        }
        return admission.status.title
    }

    private var subtitleText: String {
        if admission.isCoatCheck {
            var parts = [String(localized: "Coat Check")]
            if let claim = admission.claimCheckNumber, !claim.isEmpty {
                parts.append("#\(claim)")
            }
            parts.append(admission.nightTitle)
            parts.append(admission.price)
            if admission.quantity > 1 {
                parts.append("\(admission.quantity) coats")
            }
            return parts.joined(separator: " · ")
        }
        var parts = [admission.nightTitle, admission.price]
        if admission.quantity > 1 {
            parts.append("\(admission.quantity) covers")
        }
        if let tier = admission.tier, !tier.isEmpty {
            parts.append(tier.capitalized)
        }
        return parts.joined(separator: " · ")
    }
}
