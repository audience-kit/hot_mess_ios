//
//  PeopleViewModel.swift
//  HotMess
//

import AudienceKit
import Foundation
import Observation

extension Person {
    /// A list row's worth of person from AudienceKit GraphQL. The detail
    /// screen still loads the full person over REST by its UUID.
    init?(_ person: AudienceKit.Person, resolve: (String?) -> URL?) {
        guard let id = RecordID.uuid(person.id) else { return nil }

        self.init(
            id: id,
            name: person.name,
            pictureURL: resolve(person.page.photoUrl),
            coverURL: resolve(person.page.coverImageUrl)
        )
    }
}

@MainActor
@Observable
final class PeopleViewModel {
    private(set) var state: LoadState<[Person]> = .idle

    private let audienceKit: AudienceKitClient

    init(audienceKit: AudienceKitClient) {
        self.audienceKit = audienceKit
    }

    /// The people the audience follows, from AudienceKit GraphQL.
    func load() async {
        if state.value == nil { state = .loading }

        do {
            let people = try await audienceKit.people()
            state = .loaded(
                people
                    .sorted { ($0.order, $0.name) < ($1.order, $1.name) }
                    .compactMap { Person($0, resolve: audienceKit.url(for:)) }
            )
        } catch is CancellationError {
        } catch let error as AudienceKitError {
            state = LoadState(catching: APIError(error))
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
