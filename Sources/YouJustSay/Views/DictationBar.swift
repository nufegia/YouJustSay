import SwiftUI

struct DictationBar: View {
    let preferences: Preferences
    let session: DictationSession
    let openSettings: () -> Void
    let dismiss: () -> Void
    let resize: (CGSize) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        FloatingBarSurface {
            content
        }
        .fixedSize()
        .padding(8)
        .background {
            GeometryReader { geometry in
                Color.clear.onChange(of: geometry.size, initial: true) { resize(geometry.size) }
            }
        }
    }

    @ViewBuilder private var content: some View {
        if let error = session.error {
            if session.completed && !session.lastResult.isEmpty {
                insertionRecoveryBar(error: error)
            } else if error == "empty" {
                emptyRecoveryBar
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle")
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                            .accessibilityHidden(true)
                        Text(preferences.t(error))
                            .frame(maxWidth: 260, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                        settingsButton
                        closeButton
                    }
                    if !session.completed && (session.hasAudio || !session.original.isEmpty) {
                        HStack(spacing: 6) {
                            if !session.original.isEmpty {
                                Button(preferences.t("retryPolish")) { session.polish(preferences) }
                                Button(preferences.t("copyOriginal")) { session.deliverOriginal(preferences) }
                            } else {
                                Button(preferences.t("retry")) { session.transcribe(preferences) }
                            }
                        }
                        .buttonStyle(FloatingBarButtonStyle(prominent: true))
                        .padding(.leading, 32)
                    }
                }
            }
        } else if session.phase == .recording {
            Button { session.toggle(preferences) } label: {
                HStack(spacing: 3) {
                    ForEach(session.waveform.samples.indices, id: \.self) { index in
                        Capsule()
                            .fill(.primary.opacity(0.85))
                            .frame(width: 3, height: 3 + 17 * session.waveform.samples[index])
                    }
                }
                .frame(width: 126, height: 28)
                .contentShape(Rectangle())
                .animation(reduceMotion ? nil : .linear(duration: 0.08), value: session.waveform.samples)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(preferences.t("stop"))
            .help(preferences.t("stop"))
        } else if session.phase == .paused {
            HStack(spacing: 8) {
                Button { session.resume(preferences) } label: {
                    Label(preferences.t("resume"), systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(FloatingBarButtonStyle(prominent: true))
                Text("\(session.recoverySeconds)s")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 22)
                closeButton
            }
        } else if session.completed {
            Image(systemName: "checkmark")
                .frame(width: 32, height: 28)
                .accessibilityLabel(preferences.t(session.copiedOnly ? "copiedHint" : "inserted"))
        } else {
            HStack(spacing: 10) {
                ProgressView().controlSize(.mini).frame(width: 24)
                Text(preferences.t(session.phase.rawValue)).fixedSize()
                closeButton
            }
        }
    }

    private func insertionRecoveryBar(error: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(preferences.t(error == "insertionFailed" || error == "targetChanged" ? error + "Short" : error))
                .lineLimit(1)
                .help(preferences.t(error))
                .accessibilityLabel(preferences.t(error))
            Button(preferences.t("copyResult")) { session.copyLastResult() }
                .buttonStyle(FloatingBarButtonStyle(prominent: true))
            settingsIconButton
            closeButton
        }
    }

    private var emptyRecoveryBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(preferences.t("emptyShort"))
                .lineLimit(1)
                .help(preferences.t("empty"))
                .accessibilityLabel(preferences.t("empty"))
            if !session.original.isEmpty {
                Button(preferences.t("retryPolish")) { session.polish(preferences) }
                    .buttonStyle(FloatingBarButtonStyle(prominent: true))
                Button(preferences.t("copyOriginal")) { session.deliverOriginal(preferences) }
                    .buttonStyle(FloatingBarButtonStyle())
            } else if session.hasAudio {
                Button(preferences.t("retry")) { session.transcribe(preferences) }
                    .buttonStyle(FloatingBarButtonStyle(prominent: true))
            }
            settingsIconButton
            closeButton
        }
    }

    private var settingsIconButton: some View {
        Button {
            dismiss()
            openSettings()
        } label: {
            Image(systemName: "gearshape").font(.system(size: 12))
        }
        .buttonStyle(FloatingBarButtonStyle())
        .help(preferences.t("settings"))
        .accessibilityLabel(preferences.t("settings"))
    }

    private var settingsButton: some View {
        Button(preferences.t("settings")) {
            dismiss()
            openSettings()
        }
        .buttonStyle(FloatingBarButtonStyle(prominent: true))
        .fixedSize()
    }

    private var closeButton: some View {
        Button {
            if !session.escape() { session.discard(); dismiss() }
        } label: {
            Image(systemName: "xmark").font(.system(size: 10, weight: .semibold))
        }
        .buttonStyle(FloatingBarButtonStyle())
        .help(preferences.t("close"))
        .accessibilityLabel(preferences.t("close"))
    }
}
