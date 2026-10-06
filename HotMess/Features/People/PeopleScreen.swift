//
//  PeopleScreen.swift
//  HotMess
//

import SwiftUI

/// The people tab, replacing `PeopleViewController` — which registered its
/// refresh observer with `object: self`, so the notification it was waiting for
/// never matched and the list only ever loaded once.
struct PeopleScreen: View {
    @Environment(AppModel.self) private var model
    @State private var viewModel: PeopleViewModel?

    var body: some View {
        LoadStateView(state: viewModel?.state ?? .loading, retry: reload) { people in
            if people.isEmpty {
                ContentUnavailableView(
                    String(localized: "No One Yet"),
                    systemImage: "person.2",
                    description: Text("Nobody is listed yet.")
                )
            } else {
                List(people) { person in
                    NavigationLink(value: AppRoute.person(person.id)) {
                        PersonRow(person: person)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(String(localized: "People"))
        .task {
            ensureViewModel()
            await viewModel?.load()
        }
        .refreshable {
            await viewModel?.load()
        }
    }

    private func ensureViewModel() {
        if viewModel == nil {
            viewModel = PeopleViewModel(audienceKit: model.audienceKit)
        }
    }

    private func reload() {
        Task {
            ensureViewModel()
            await viewModel?.load()
        }
    }
}
