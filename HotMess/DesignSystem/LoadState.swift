//
//  LoadState.swift
//  HotMess
//

import SwiftUI

/// Where a screen's data currently stands.
///
/// The old view controllers had no failure state at all — a request that failed
/// left the table empty with a spinner that had already been dismissed.
enum LoadState<Value: Sendable>: Sendable {
    case idle
    case loading
    case loaded(Value)
    case failed(message: String, isRetryable: Bool)

    var value: Value? {
        if case let .loaded(value) = self { return value }
        return nil
    }

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    init(catching error: any Error) {
        if let apiError = error as? APIError {
            self = .failed(
                message: apiError.errorDescription ?? apiError.localizedDescription,
                isRetryable: apiError.isRetryable
            )
        } else {
            self = .failed(message: error.localizedDescription, isRetryable: true)
        }
    }
}

/// Renders the loading and failure states so each screen only has to describe
/// its content.
struct LoadStateView<Value: Sendable, Content: View>: View {
    let state: LoadState<Value>
    var retry: (() -> Void)?
    @ViewBuilder var content: (Value) -> Content

    var body: some View {
        switch state {
        case .idle, .loading:
            ProgressView()
                .controlSize(.large)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case let .loaded(value):
            content(value)

        case let .failed(message, isRetryable):
            ContentUnavailableView {
                Label(String(localized: "Something went wrong"), systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                if isRetryable, let retry {
                    Button(String(localized: "Try Again"), action: retry)
                        .buttonStyle(.borderedProminent)
                }
            }
        }
    }
}
