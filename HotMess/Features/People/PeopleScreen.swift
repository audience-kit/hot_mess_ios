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
                    description: Text("Nobody is listed near you right now.")
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
        .task(id: model.location.locale?.id) {
            ensureViewModel()
            await viewModel?.load(localeID: model.location.locale?.id)
        }
        .refreshable {
            await viewModel?.load(localeID: model.location.locale?.id)
        }
    }

    private func ensureViewModel() {
        if viewModel == nil {
            viewModel = PeopleViewModel(api: model.api)
        }
    }

    private func reload() {
        Task {
            ensureViewModel()
            await viewModel?.load(localeID: model.location.locale?.id)
        }
    }
}
