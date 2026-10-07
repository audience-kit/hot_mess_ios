//
//  DetailSection.swift
//  HotMess
//

import SwiftUI

/// An inset grouped section for detail screens that scroll in a `ScrollView`
/// rather than a `List`, so their hero can run edge to edge.
///
/// Each child view becomes a row with a divider between rows. A section with no
/// rows draws nothing, header included.
struct DetailSection<Content: View, Footer: View>: View {
    let title: String?
    let content: Content
    let footer: Footer

    init(_ title: String? = nil, @ViewBuilder content: () -> Content, @ViewBuilder footer: () -> Footer) {
        self.title = title
        self.content = content()
        self.footer = footer()
    }

    var body: some View {
        Group(subviews: content) { rows in
            if !rows.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    if let title {
                        Text(title)
                            .font(.hotMess(.subheadline, semibold: true))
                            .foregroundStyle(.secondary)
                            .accessibilityAddTraits(.isHeader)
                            .padding(.horizontal, 20)
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(rows) { row in
                            row
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 11)

                            if row.id != rows.last?.id {
                                Divider()
                                    .padding(.leading, 20)
                            }
                        }
                    }
                    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: CardMetrics.cornerRadius))

                    footer
                        .padding(.horizontal, 20)
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

extension DetailSection where Footer == EmptyView {
    init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.init(title, content: content) { EmptyView() }
    }
}

/// A navigation row with a disclosure chevron, as a `List` would draw it.
struct DetailLink<Label: View>: View {
    let route: AppRoute
    @ViewBuilder var label: Label

    var body: some View {
        NavigationLink(value: route) {
            HStack(spacing: 8) {
                label
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
