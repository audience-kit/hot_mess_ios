//
//  DoorScreen.swift
//  HotMess
//

import SwiftUI
import UIKit

/// Door mode, for staff at venues the user can work the door at: scan a
/// pass and see ADMIT, RE-ENTRY or why not, full screen, for a moment.
struct DoorScreen: View {
    let venues: [DoorVenue]

    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @State private var viewModel: DoorViewModel?
    @State private var camera = CameraAccess.unknown

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let viewModel {
                scanner(viewModel)
                overlay(viewModel)

                if let result = viewModel.result {
                    ScanResultView(result: result)
                        .onTapGesture { viewModel.dismissResult() }
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
        }
        .animation(HotMessMotion.quick, value: viewModel?.result)
        .navigationTitle(String(localized: "Door"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task {
            if viewModel == nil {
                viewModel = DoorViewModel(api: model.api, venues: venues)
            }
            camera = await CameraAccess.request()
            await viewModel?.refreshCounts()
        }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .alert(
            String(localized: "Couldn't Check Pass"),
            isPresented: Binding(
                get: { viewModel?.errorMessage != nil },
                set: { if !$0 { viewModel?.errorMessage = nil } }
            )
        ) {
            Button(String(localized: "OK"), role: .cancel) {}
        } message: {
            Text(viewModel?.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private func scanner(_ viewModel: DoorViewModel) -> some View {
        switch camera {
        case .granted:
            QRScannerView { code in viewModel.scanned(code) }
                .ignoresSafeArea()
                .accessibilityLabel(String(localized: "Camera. Point it at a pass."))
        case .denied:
            ContentUnavailableView {
                Label(String(localized: "Camera Off"), systemImage: "camera")
            } description: {
                Text("Allow Hot Mess to use the camera in Settings to scan passes.")
            } actions: {
                Button(String(localized: "Open Settings")) {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .buttonStyle(.borderedProminent)
            }
            .environment(\.colorScheme, .dark)
        case .unavailable:
            ContentUnavailableView(
                String(localized: "No Camera"),
                systemImage: "camera",
                description: Text("Scanning passes needs a camera.")
            )
            .environment(\.colorScheme, .dark)
        case .unknown:
            ProgressView()
                .tint(.white)
        }
    }

    private func overlay(_ viewModel: DoorViewModel) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                venuePicker(viewModel)
                Spacer(minLength: 8)
                if let counts = viewModel.selectedCounts {
                    GlassPill(String(localized: "\(counts.paidCount) paid · \(counts.checkedInCount) in"))
                        .font(.hotMess(.subheadline, semibold: true))
                        .monospacedDigit()
                        .accessibilityLabel(String(localized: "\(counts.paidCount) paid, \(counts.checkedInCount) checked in"))
                }
            }

            Spacer()

            // The target the pass goes in.
            RoundedRectangle(cornerRadius: CardMetrics.cornerRadius)
                .strokeBorder(.white.opacity(0.8), style: StrokeStyle(lineWidth: 3, dash: [18, 10]))
                .frame(width: 240, height: 240)
                .accessibilityHidden(true)

            Spacer()

            GlassPill {
                HStack(spacing: 8) {
                    if viewModel.isChecking {
                        ProgressView().tint(.white)
                        Text("Checking…")
                    } else {
                        Image(systemName: "qrcode.viewfinder")
                        Text("Point the camera at a pass")
                    }
                }
                .font(.hotMess(.subheadline, semibold: true))
            }
        }
        .padding(16)
        .opacity(camera == .granted ? 1 : 0)
    }

    @ViewBuilder
    private func venuePicker(_ viewModel: DoorViewModel) -> some View {
        let name = viewModel.selectedVenue?.name ?? String(localized: "Venue")

        if viewModel.venues.count > 1 {
            Menu {
                ForEach(viewModel.venues) { venue in
                    Button {
                        viewModel.select(venue)
                    } label: {
                        if venue.id == viewModel.selectedVenueID {
                            Label(venue.name, systemImage: "checkmark")
                        } else {
                            Text(venue.name)
                        }
                    }
                }
            } label: {
                GlassPill {
                    HStack(spacing: 4) {
                        Text(name).lineLimit(1)
                        Image(systemName: "chevron.down").font(.caption.weight(.semibold))
                    }
                    .font(.hotMess(.subheadline, semibold: true))
                }
            }
            .accessibilityLabel(String(localized: "Door at \(name). Change venue."))
        } else {
            GlassPill(name)
                .font(.hotMess(.subheadline, semibold: true))
                .lineLimit(1)
        }
    }
}

/// A scan's answer, full screen: green to let them in, amber for re-entry,
/// red for anything else, with the message and the buyer's photo so the door
/// can match the face.
struct ScanResultView: View {
    let result: ScanResult

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: result.outcome.systemImage)
                    .font(.system(size: 88, weight: .bold))

                Text(result.outcome.title)
                    .font(.hotMess(fixedSize: 48, semibold: true))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                if let admission = result.admission, admission.userPhotoURL != nil || admission.userName != nil {
                    Avatar(
                        url: admission.userPhotoURL,
                        initials: admission.userName?.initialsForDisplay,
                        size: 120
                    )
                }

                Text(result.message)
                    .font(.hotMess(.title2, semibold: true))
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(foreground)
            .padding(32)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(String(localized: "Dismisses the result."))
    }

    private var background: Color {
        switch result.outcome {
        case .admit: .hotMessDoorAdmit
        case .reEntry: .hotMessDoorReEntry
        default: .hotMessDoorRefuse
        }
    }

    /// Dark text on amber, which white can't hold contrast on.
    private var foreground: Color {
        result.outcome == .reEntry ? .hotMessPhotoInk : .white
    }
}
