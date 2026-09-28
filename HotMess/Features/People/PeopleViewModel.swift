//
//  PeopleViewModel.swift
//  HotMess
//

import Foundation
import Observation

@MainActor
@Observable
final class PeopleViewModel {
    private(set) var state: LoadState<[Person]> = .idle

    private let api: HotMessAPI

    init(api: HotMessAPI) {
        self.api = api
    }

    func load(localeID: UUID?) async {
        guard let localeID else {
            state = .failed(
                message: String(localized: "We need your location to find people near you."),
                isRetryable: false
            )
            return
        }

        if state.value == nil { state = .loading }

        do {
            state = .loaded(try await api.people(in: localeID))
        } catch is CancellationError {
        } catch {
            state = LoadState(catching: error)
        }
    }
}

@MainActor
@Observable
final class PersonViewModel {
    private(set) var state: LoadState<PersonDetail> = .idle

    private let api: HotMessAPI
    private let personID: UUID

    init(api: HotMessAPI, personID: UUID) {
        self.api = api
        self.personID = personID
    }

    func load() async {
        if state.value == nil { state = .loading }

        do {
            state = .loaded(try await api.person(personID))
        } catch is CancellationError {
        } catch {
            state = LoadState(catching: error)
        }
    }
}
