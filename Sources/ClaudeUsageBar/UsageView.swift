import AppKit
import SwiftUI

struct UsageView: View {
    @EnvironmentObject private var model: UsageModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if let error = model.error, model.snapshot != nil {
                // We still have (stale) numbers, but the last refresh failed —
                // say so visibly rather than hiding it in a tooltip.
                errorBanner(error)
            }

            if let snapshot = model.snapshot {
                content(snapshot)
            } else if let error = model.error {
                errorView(error)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            }

            Divider()
            footer
        }
        .padding(16)
        .frame(width: 292)
        .onAppear { Task { await model.refreshIfStale() } }
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Text("Claude Usage")
                .font(.headline)
            Spacer()
        }
    }

    private func errorBanner(_ error: UsageError) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(error.errorDescription ?? "Refresh failed")
                .font(.caption.weight(.medium))
                .foregroundStyle(.orange)
            Text(error.hint)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: Content

    @ViewBuilder
    private func content(_ snapshot: UsageSnapshot) -> some View {
        let rings = snapshot.limits.filter { $0.kind == "session" || $0.kind == "weekly_all" }
        let rows = snapshot.limits.filter { $0.kind != "session" && $0.kind != "weekly_all" }

        HStack(spacing: 12) {
            ForEach(rings) { limit in
                LimitRing(limit: limit)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 4)

        if !rows.isEmpty {
            VStack(spacing: 10) {
                ForEach(rows) { LimitRow(limit: $0) }
            }
        }

        if let spend = snapshot.spend, spend.enabled == true,
           let used = spend.used, let limit = spend.limit {
            HStack {
                Text("Extra usage")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(used.formatted) / \(limit.formatted)")
                    .font(.subheadline.weight(.medium))
                    .monospacedDigit()
            }
            .padding(10)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: Error

    private func errorView(_ error: UsageError) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundStyle(.orange)
            Text(error.errorDescription ?? "Something went wrong")
                .font(.subheadline.weight(.medium))
            Text(error.hint)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 12) {
            if let updated = model.lastUpdated {
                Text("Updated \(updated.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Button {
                NSWorkspace.shared.open(URL(string: "https://claude.ai/settings/usage")!)
            } label: {
                Image(systemName: "arrow.up.forward.square")
            }
            .help("Open usage settings on claude.ai")

            Button {
                Task { await model.refresh() }
            } label: {
                if model.isLoading {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .disabled(model.isLoading)
            .help("Refresh now")

            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .help("Quit")
        }
        .buttonStyle(.borderless)
    }
}

// MARK: - Ring

struct LimitRing: View {
    let limit: UsageSnapshot.Limit

    private var percent: Double { limit.percent ?? 0 }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 8)
                Circle()
                    .trim(from: 0, to: max(0.004, min(1, percent / 100)))
                    .stroke(
                        limitTint(for: percent, severity: limit.severity).gradient,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                Text("\(Int(percent))%")
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .monospacedDigit()
            }
            .frame(width: 74, height: 74)

            Text(limit.label)
                .font(.caption.weight(.medium))
            if let resetsAt = limit.resetsAt {
                Text(resetText(resetsAt))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Row (model-scoped limits)

struct LimitRow: View {
    let limit: UsageSnapshot.Limit

    private var percent: Double { limit.percent ?? 0 }

    var body: some View {
        VStack(spacing: 3) {
            HStack {
                Text(limit.label)
                    .font(.subheadline)
                Spacer()
                Text("\(Int(percent))%")
                    .font(.subheadline.weight(.medium))
                    .monospacedDigit()
            }
            ProgressView(value: min(1, percent / 100))
                .tint(limitTint(for: percent, severity: limit.severity))
            if let resetsAt = limit.resetsAt {
                HStack {
                    Spacer()
                    Text(resetText(resetsAt))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Shared tint

func limitTint(for percent: Double, severity: String?) -> Color {
    if let severity, severity != "normal" { return .red }
    if percent >= 90 { return .red }
    if percent >= 70 { return .orange }
    return .accentColor
}
