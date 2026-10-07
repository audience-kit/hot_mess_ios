//
//  PassScreen.swift
//  HotMess
//

import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

/// A cover pass, to show at the door: who it's for, the venue and night, and
/// a QR code the phone makes every 30 seconds from the pass's secret, so it
/// works with no signal. A colour band keeps moving so staff can tell it's
/// live and not a screenshot. The screen stays awake and bright while shown.
struct PassScreen: View {
    @State private var admission: Admission

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @State private var lighting = PassLighting()
    @State private var isConfirmingRefund = false
    @State private var isRefunding = false
    @State private var refundError: String?

    init(admission: Admission) {
        _admission = State(initialValue: admission)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    holder
                    code
                    details
                    refundButton
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 24)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(String(localized: "Pass"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Done")) { dismiss() }
                }
            }
        }
        .onAppear { lighting.isOn = admission.isPaid }
        .onDisappear { lighting.isOn = false }
        .onChange(of: scenePhase) { _, phase in
            lighting.isOn = phase == .active && admission.isPaid
        }
        .confirmationDialog(
            String(localized: "Refund your cover?"),
            isPresented: $isConfirmingRefund,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Refund \(admission.price)"), role: .destructive) {
                Task { await refund() }
            }
        } message: {
            Text("The pass stops working and the money goes back to how you paid.")
        }
        .alert(
            String(localized: "Couldn't Refund"),
            isPresented: Binding(
                get: { refundError != nil },
                set: { if !$0 { refundError = nil } }
            )
        ) {
            Button(String(localized: "OK"), role: .cancel) {}
        } message: {
            Text(refundError ?? "")
        }
    }

    // MARK: - Sections

    private var holder: some View {
        VStack(spacing: 8) {
            Avatar(url: photoURL, initials: holderName.initialsForDisplay, size: 88)

            Text(holderName.firstNameForDisplay)
                .font(.hotMess(.title2, semibold: true))

            Text(admission.venueName)
                .font(.hotMess(.title, semibold: true))
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            Text(nightLine)
                .font(.hotMess(.subheadline))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var code: some View {
        if admission.isPaid, admission.passSecret != nil {
            VStack(spacing: 0) {
                LiveBand()
                    .frame(height: 14)

                PassCode(admission: admission)
                    .frame(maxWidth: 280)
                    .aspectRatio(1, contentMode: .fit)
                    .padding(20)
                    .accessibilityLabel(String(localized: "Pass QR code"))

                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text("New code in \(CoverPass.secondsRemaining(at: context.date))s")
                        .font(.hotMess(.footnote))
                        .monospacedDigit()
                        .foregroundStyle(Color.hotMessPhotoInk.opacity(0.6))
                }
                .padding(.bottom, 12)

                LiveBand(reversed: true)
                    .frame(height: 14)
            }
            .frame(maxWidth: .infinity)
            .background(.white)
            .clipShape(.rect(cornerRadius: CardMetrics.cornerRadius))
        } else {
            VStack(spacing: 8) {
                Image(systemName: admission.isPaid ? "iphone.slash" : "xmark.circle")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)

                Text(admission.isPaid ? String(localized: "Open this pass on the phone that paid for it.") : admission.status.title)
                    .font(.hotMess(.headline, semibold: true))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(32)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: CardMetrics.cornerRadius))
        }
    }

    private var details: some View {
        VStack(spacing: 0) {
            InfoRow(title: String(localized: "Cover"), value: admission.price)
                .padding(.horizontal, 20)
                .padding(.vertical, 11)

            Divider().padding(.leading, 20)

            InfoRow(title: String(localized: "Status"), value: statusText)
                .padding(.horizontal, 20)
                .padding(.vertical, 11)
        }
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: CardMetrics.cornerRadius))
    }

    @ViewBuilder
    private var refundButton: some View {
        if admission.isRefundable {
            Button(role: .destructive) {
                isConfirmingRefund = true
            } label: {
                HStack(spacing: 8) {
                    if isRefunding { ProgressView() }
                    Text("Refund")
                        .font(.hotMess(.body, semibold: true))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(isRefunding)
            .accessibilityIdentifier("pass.refund")
        }
    }

    // MARK: - Helpers

    /// The buyer's name as the API has it, falling back to the signed-in user.
    private var holderName: String {
        admission.userName ?? model.session.user?.name ?? ""
    }

    private var photoURL: URL? {
        admission.userPhotoURL ?? model.session.userID.map(model.configuration.avatarURL(forUserID:))
    }

    private var nightLine: String {
        [admission.nightTitle, admission.eventName].compactMap(\.self).joined(separator: " · ")
    }

    private var statusText: String {
        guard admission.isPaid, let checkedInAt = admission.checkedInAt else { return admission.status.title }
        return String(localized: "In at \(checkedInAt.formatted(date: .omitted, time: .shortened))")
    }

    private func refund() async {
        isRefunding = true
        defer { isRefunding = false }

        do {
            admission = try await model.checkout.refund(admission)
            lighting.isOn = admission.isPaid
        } catch {
            refundError = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }
}

/// A pass's QR code, made again at each 30-second window.
struct PassCode: View {
    let admission: Admission

    var body: some View {
        // Ticks on the window boundaries, so the code is drawn twice a minute
        // rather than every frame.
        let start = Date(timeIntervalSince1970: Double(CoverPass.window(at: .now) * CoverPass.windowLength))

        TimelineView(.periodic(from: start, by: Double(CoverPass.windowLength))) { context in
            QRCodeImage(text: admission.passCode(at: context.date) ?? "")
        }
    }
}

/// A QR code drawn with CoreImage, crisp at any size.
struct QRCodeImage: View {
    let text: String

    var body: some View {
        if !text.isEmpty, let image = QRCodeRenderer.image(for: text) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
        } else {
            Color.clear
        }
    }
}

enum QRCodeRenderer {
    /// CIContext is thread-safe and costly to make, so one is shared.
    nonisolated(unsafe) private static let context = CIContext()

    static func image(for text: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"

        guard let output = filter.outputImage else { return nil }

        let scaled = output.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

/// A band of colour that keeps sliding, so door staff can tell a pass is live
/// on the phone and not a screenshot.
struct LiveBand: View {
    var reversed = false

    /// Seconds for the pattern to slide one width.
    private static let period: Double = 4

    private static var colors: [Color] {
        let cycle = [Color.hotMessAccent, Color.hotMessPresencePush, Color.hotMessPresenceOnline]
        return cycle + cycle + [cycle[0]]
    }

    var body: some View {
        TimelineView(.animation) { context in
            let progress = context.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: Self.period) / Self.period
            let phase = reversed ? 1 - progress : progress

            GeometryReader { proxy in
                // The gradient is two widths of a pattern that repeats every
                // width, so sliding it one width loops without a seam.
                LinearGradient(colors: Self.colors, startPoint: .leading, endPoint: .trailing)
                    .frame(width: proxy.size.width * 2, height: proxy.size.height)
                    .offset(x: -proxy.size.width * phase)
            }
        }
        .clipped()
        .accessibilityHidden(true)
    }
}

/// Keeps the screen awake and at full brightness while a pass is showing,
/// and puts the brightness back after.
@MainActor
final class PassLighting {
    private var savedBrightness: CGFloat?

    var isOn = false {
        didSet {
            guard isOn != oldValue else { return }
            apply()
        }
    }

    private var screen: UIScreen? {
        UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.screen }.first
    }

    private func apply() {
        UIApplication.shared.isIdleTimerDisabled = isOn

        guard let screen else { return }
        if isOn {
            if savedBrightness == nil { savedBrightness = screen.brightness }
            screen.brightness = 1
        } else if let savedBrightness {
            screen.brightness = savedBrightness
            self.savedBrightness = nil
        }
    }
}
