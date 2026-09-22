//
//  NowViewModel.swift
//  HotMess
//

import Foundation
import Observation

@MainActor
@Observable
final class NowViewModel {
    private(set) var state: LoadState<Now> = .idle

    private let api: HotMessAPI

    init(api: HotMessAPI) {
        self.api = api
    }

    func load(near coordinates: Coordinates?) async {
        if state.value == nil { state = .loading }

        do {
            state = .loaded(try await api.now(near: coordinates))
        } catch is CancellationError {
            // The view went away; leave whatever was on screen alone.
        } catch {
            state = LoadState(catching: error)
        }
    }
}
