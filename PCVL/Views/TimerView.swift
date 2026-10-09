import SwiftUI
import AppKit

// MARK: - Timer Metrics

/// Size values for the timer layout. Compact matches the 300x190 popup; expanded
/// scales everything up to fill the zoomed (fullscreen) panel.
private struct TimerMetrics {
    let isExpanded: Bool
    let scale: CGFloat
    let timeFontSize: CGFloat
    let displayMaxWidth: CGFloat

    init(size: CGSize, isExpanded: Bool) {
        self.isExpanded = isExpanded
        guard isExpanded else {
            scale = 1
            timeFontSize = 36
            displayMaxWidth = .infinity
            return
        }
        let fit = min(size.width / 300, size.height / 190)
        scale = min(max(fit * 0.42, 1.4), 2.6)
        timeFontSize = min(size.width * 0.17, size.height * 0.30)
        displayMaxWidth = min(size.width * 0.62, 1100)
    }
}

// MARK: - Timer View

struct TimerView: View {
    @ObservedObject var viewModel: TimerViewModel
    @ObservedObject var theme: ThemeManager
    var isExpanded: Bool = false
    var onToggleFullscreen: () -> Void

    @State private var scrollAccumulator: CGFloat = 0
    @State private var lastHapticFeedbackTime: CFTimeInterval = 0
    @State private var isPrimaryButtonHovering = false
    @State private var isResetButtonHovering = false
    @State private var isFullscreenButtonHovering = false
    @State private var hoveringMode: TimerMode?

    var body: some View {
        GeometryReader { geo in
            layout(TimerMetrics(size: geo.size, isExpanded: isExpanded))
        }
        .onAppear { viewModel.refreshTodayStats() }
    }

    private func layout(_ m: TimerMetrics) -> some View {
        VStack(spacing: 0) {
            // Top row: mode toggle + label
            HStack {
                modeToggle(m)
                Spacer()
                Text(viewModel.modeLabel)
                    .font(theme.currentFont.font(size: 8 * m.scale, weight: .semibold))
                    .tracking(1.5 * m.scale)
                    .foregroundColor(theme.colors.textSecondary)
            }
            .padding(.horizontal, 16 * m.scale)
            .padding(.top, 8 * m.scale)

            Spacer()

            // Center: reset | time + progress line | fullscreen
            HStack(spacing: 12 * m.scale) {
                circleButton(
                    icon: "arrow.counterclockwise",
                    iconSize: 11,
                    isHovering: $isResetButtonHovering,
                    metrics: m
                ) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        viewModel.reset()
                    }
                }
                .disabled(viewModel.isIdle)
                .opacity(viewModel.isIdle ? 0.3 : 1)

                // Timer display — clickable
                timerDisplay(m)
                    .frame(maxWidth: m.displayMaxWidth)
                    .overlay {
                        TimerScrollWheelMonitor(
                            isEnabled: viewModel.editableCountdownDuration != nil,
                            onScroll: handleScrollWheel
                        )
                        .allowsHitTesting(false)
                    }
                    .onTapGesture(perform: primaryButtonTapped)

                circleButton(
                    icon: m.isExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
                    iconSize: 9,
                    isHovering: $isFullscreenButtonHovering,
                    metrics: m,
                    action: onToggleFullscreen
                )
            }
            .padding(.horizontal, 16 * m.scale)
            .frame(maxWidth: .infinity)

            Spacer()

            if m.isExpanded {
                todaySummary(m)
                    .padding(.horizontal, 16 * m.scale)
                    .padding(.bottom, 20 * m.scale)
            }
        }
    }

    // MARK: - Circle Button

    private func circleButton(
        icon: String,
        iconSize: CGFloat,
        isHovering: Binding<Bool>,
        metrics m: TimerMetrics,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(theme.currentFont.font(size: iconSize * m.scale, weight: .medium))
                .foregroundColor(theme.colors.textSecondary)
                .frame(width: 26 * m.scale, height: 26 * m.scale)
                .background(theme.colors.surface)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.16), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: .black.opacity(isHovering.wrappedValue ? 0.30 : 0.24),
                    radius: isHovering.wrappedValue ? 9 : 3,
                    x: 0,
                    y: isHovering.wrappedValue ? 3 : 1
                )
        }
        .buttonStyle(SpringButtonStyle(kind: .secondary, theme: theme))
        .scaleEffect(isHovering.wrappedValue ? 1.05 : 1)
        .animation(.spring(response: 0.30, dampingFraction: 0.60), value: isHovering.wrappedValue)
        .onHover { hovering in
            isHovering.wrappedValue = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }

    // MARK: - Mode Toggle

    private func modeToggle(_ m: TimerMetrics) -> some View {
        HStack(spacing: 0) {
            ForEach(TimerMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.mode = mode
                    }
                } label: {
                    Text(mode == .countDown ? "Timer" : "Stopwatch")
                        .font(theme.currentFont.font(size: 9 * m.scale, weight: .medium))
                        .foregroundColor(viewModel.mode == mode ? theme.colors.accent : theme.colors.textSecondary)
                        .padding(.horizontal, 8 * m.scale)
                        .padding(.vertical, 4 * m.scale)
                        .background(
                            viewModel.mode == mode
                                ? theme.colors.accent.opacity(0.12)
                                : Color.clear
                        )
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(
                                    LinearGradient(
                                        colors: viewModel.mode == mode
                                            ? [Color.white.opacity(0.16), .clear]
                                            : [.clear, .clear],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(
                            color: .black.opacity(viewModel.mode == mode && hoveringMode == mode ? 0.30 : (viewModel.mode == mode ? 0.24 : 0)),
                            radius: viewModel.mode == mode ? (hoveringMode == mode ? 9 : 3) : 0,
                            x: 0,
                            y: viewModel.mode == mode ? (hoveringMode == mode ? 3 : 1) : 0
                        )
                }
                .buttonStyle(SpringButtonStyle(kind: .secondary, theme: theme))
                .disabled(!viewModel.isIdle)
                .opacity(viewModel.isIdle ? 1 : (viewModel.mode == mode ? 1 : 0.4))
                .scaleEffect(hoveringMode == mode ? 1.05 : 1)
                .animation(.spring(response: 0.30, dampingFraction: 0.60), value: hoveringMode)
                .onHover { hovering in
                    hoveringMode = hovering ? mode : (hoveringMode == mode ? nil : hoveringMode)
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }
        }
        .padding(2 * m.scale)
        .background(theme.colors.surface)
        .clipShape(Capsule())
    }

    // MARK: - Timer Display (time + progress line)

    private func timerDisplay(_ m: TimerMetrics) -> some View {
        VStack(spacing: 6 * m.scale) {
            // Time text
            Text(viewModel.engine.formattedTime)
                .font(theme.timerFont(size: m.timeFontSize, weight: .thin))
                .foregroundColor(theme.colors.text)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            // Progress line
            let lineHeight = min(3 * m.scale, 6)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: lineHeight / 2)
                        .fill(theme.colors.ringTrack)
                        .frame(height: lineHeight)

                    // Fill (countdown only)
                    if viewModel.mode == .countDown {
                        RoundedRectangle(cornerRadius: lineHeight / 2)
                            .fill(viewModel.isBreak ? theme.colors.breakRing : theme.colors.timerRing)
                            .frame(width: geo.size.width * viewModel.engine.progress, height: lineHeight)
                            .animation(.linear(duration: 0.3), value: viewModel.engine.progress)
                    }
                }
            }
            .frame(height: lineHeight)

            if m.isExpanded, let next = viewModel.nextPhaseLabel {
                Text(next.uppercased())
                    .font(theme.currentFont.font(size: 8 * m.scale, weight: .semibold))
                    .tracking(1.5 * m.scale)
                    .foregroundColor(theme.colors.textSecondary)
                    .padding(.vertical, 4 * m.scale)
            }

            primaryButton(m)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onChange(of: viewModel.editableCountdownDuration) { _, _ in
            scrollAccumulator = 0
        }
    }

    // MARK: - Today Summary (expanded only)

    private func todaySummary(_ m: TimerMetrics) -> some View {
        HStack(spacing: 8 * m.scale) {
            summaryCard(value: viewModel.liveTodayFocusText, label: "Focus today", metrics: m)
            summaryCard(value: "\(viewModel.todayStats.sessions)", label: "Sessions today", metrics: m)
            summaryCard(
                value: "\(viewModel.todayStats.streak)d",
                label: "Streak",
                valueColor: theme.colors.accent,
                metrics: m
            )
        }
        .frame(maxWidth: min(m.displayMaxWidth, 520 * m.scale))
    }

    private func summaryCard(value: String, label: String, valueColor: Color? = nil, metrics m: TimerMetrics) -> some View {
        VStack(spacing: 2 * m.scale) {
            Text(value)
                .font(theme.currentFont.font(size: 15 * m.scale, weight: .bold, design: .rounded))
                .foregroundColor(valueColor ?? theme.colors.text)
                .contentTransition(.numericText())
            Text(label.uppercased())
                .font(theme.currentFont.font(size: 7 * m.scale, weight: .medium))
                .foregroundColor(theme.colors.textSecondary)
                .tracking(0.5 * m.scale)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8 * m.scale)
        .background(theme.colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8 * m.scale))
        .overlay(RoundedRectangle(cornerRadius: 8 * m.scale).stroke(theme.colors.text.opacity(0.06), lineWidth: 0.5))
    }

    // MARK: - Primary Button

    private var primaryButtonLabel: String {
        if viewModel.isCompleted {
            return "Skip"
        } else if viewModel.isRunning {
            return "Pause"
        } else if viewModel.isPaused {
            return "Resume"
        } else {
            return "Start"
        }
    }

    private func primaryButtonTapped() {
        withAnimation(.easeInOut(duration: 0.15)) {
            if viewModel.isCompleted {
                if viewModel.isBreak {
                    viewModel.skipToWork()
                } else {
                    viewModel.skipToBreak()
                }
            } else if viewModel.isRunning {
                viewModel.pause()
            } else {
                viewModel.start()
            }
        }
    }

    private func primaryButton(_ m: TimerMetrics) -> some View {
        Button(action: primaryButtonTapped) {
            Text(primaryButtonLabel)
                .font(theme.currentFont.font(size: 11.5 * m.scale, weight: .semibold))
                .foregroundColor(viewModel.isRunning ? theme.colors.text : theme.colors.background)
                .frame(minWidth: 78 * m.scale, minHeight: 25 * m.scale)
                .padding(.horizontal, 15 * m.scale)
                .background(viewModel.isRunning ? theme.colors.text.opacity(0.12) : theme.colors.accent)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.16), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: .black.opacity(isPrimaryButtonHovering ? 0.30 : 0.24),
                    radius: isPrimaryButtonHovering ? 9 : 3,
                    x: 0,
                    y: isPrimaryButtonHovering ? 3 : 1
                )
        }
        .buttonStyle(SpringButtonStyle(kind: .primary, theme: theme))
        .scaleEffect(isPrimaryButtonHovering ? 1.05 : 1)
        .animation(.spring(response: 0.30, dampingFraction: 0.60), value: isPrimaryButtonHovering)
        .onHover { hovering in
            isPrimaryButtonHovering = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }

    private func handleScrollWheel(_ deltaY: CGFloat) {
        guard let editableDuration = viewModel.editableCountdownDuration else {
            scrollAccumulator = 0
            return
        }

        scrollAccumulator += deltaY

        while abs(scrollAccumulator) >= TimerScrollWheelMonitor.scrollThreshold {
            let direction = scrollAccumulator > 0 ? 1 : -1
            scrollAccumulator -= CGFloat(direction) * TimerScrollWheelMonitor.scrollThreshold
            viewModel.adjustDuration(editableDuration, byMinutes: direction * editableDuration.stepMinutes)

            performHapticFeedbackIfNeeded()
        }
    }

    private func performHapticFeedbackIfNeeded() {
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastHapticFeedbackTime >= 0.08 else { return }

        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        lastHapticFeedbackTime = now
    }
}

// MARK: - Scroll Wheel Monitor

private struct TimerScrollWheelMonitor: NSViewRepresentable {
    static let scrollThreshold: CGFloat = 30

    var isEnabled: Bool
    var onScroll: (CGFloat) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.installMonitor()
        context.coordinator.view = view
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.isEnabled = isEnabled
        context.coordinator.onScroll = onScroll
        context.coordinator.view = nsView
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.stop()
    }

    final class Coordinator {
        var isEnabled = false
        var onScroll: (CGFloat) -> Void = { _ in }

        weak var view: NSView?
        private var monitor: Any?

        func installMonitor() {
            guard monitor == nil else { return }

            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                self?.handle(event)
                return event
            }
        }

        func stop() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
            monitor = nil
            view = nil
        }

        deinit {
            stop()
        }

        private func handle(_ event: NSEvent) {
            guard isEnabled, event.momentumPhase.isEmpty else { return }
            guard let view, view.window != nil else { return }

            let point = view.convert(event.locationInWindow, from: nil)
            guard view.bounds.contains(point) else { return }

            onScroll(-event.scrollingDeltaY)
        }
    }
}
