import SwiftUI
import AppKit

// MARK: - Timer View

struct TimerView: View {
    @ObservedObject var viewModel: TimerViewModel
    @ObservedObject var theme: ThemeManager
    var onToggleFullscreen: () -> Void

    @State private var scrollAccumulator: CGFloat = 0
    @State private var lastHapticFeedbackTime: CFTimeInterval = 0

    var body: some View {
        VStack(spacing: 0) {
            // Top row: mode toggle + label
            HStack {
                modeToggle
                Spacer()
                Text(viewModel.modeLabel)
                    .font(theme.currentFont.font(size: 8, weight: .semibold))
                    .tracking(1.5)
                    .foregroundColor(theme.colors.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Spacer()

            // Center: reset | time + progress line | fullscreen
            HStack(spacing: 12) {
                // Reset button
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        viewModel.reset()
                    }
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(theme.currentFont.font(size: 11, weight: .medium))
                        .foregroundColor(theme.colors.textSecondary)
                        .frame(width: 26, height: 26)
                        .background(theme.colors.surface)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isIdle)
                .opacity(viewModel.isIdle ? 0.3 : 1)

                // Timer display — clickable
                timerDisplay
                    .overlay {
                        TimerScrollWheelMonitor(
                            isEnabled: viewModel.editableCountdownDuration != nil,
                            onScroll: handleScrollWheel
                        )
                        .allowsHitTesting(false)
                    }
                    .onTapGesture {
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

                // Fullscreen button
                Button {
                    onToggleFullscreen()
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(theme.currentFont.font(size: 9, weight: .medium))
                        .foregroundColor(theme.colors.textSecondary)
                        .frame(width: 26, height: 26)
                        .background(theme.colors.surface)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)

            Spacer()
        }
    }

    // MARK: - Mode Toggle

    private var modeToggle: some View {
        HStack(spacing: 0) {
            ForEach(TimerMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.mode = mode
                    }
                } label: {
                    Text(mode == .countDown ? "Timer" : "Stopwatch")
                        .font(theme.currentFont.font(size: 9, weight: .medium))
                        .foregroundColor(viewModel.mode == mode ? theme.colors.accent : theme.colors.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            viewModel.mode == mode
                                ? theme.colors.accent.opacity(0.12)
                                : Color.clear
                        )
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.isIdle)
                .opacity(viewModel.isIdle ? 1 : (viewModel.mode == mode ? 1 : 0.4))
            }
        }
        .padding(2)
        .background(theme.colors.surface)
        .clipShape(Capsule())
    }

    // MARK: - Timer Display (time + progress line)

    private var timerDisplay: some View {
        VStack(spacing: 6) {
            // Time text
            Text(viewModel.engine.formattedTime)
                .font(theme.timerFont(size: 36, weight: .thin))
                .foregroundColor(theme.colors.text)
                .contentTransition(.numericText())

            // Progress line
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(theme.colors.ringTrack)
                        .frame(height: 3)

                    // Fill (countdown only)
                    if viewModel.mode == .countDown {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(viewModel.isBreak ? theme.colors.breakRing : theme.colors.timerRing)
                            .frame(width: geo.size.width * viewModel.engine.progress, height: 3)
                            .animation(.linear(duration: 0.3), value: viewModel.engine.progress)
                    }
                }
            }
            .frame(height: 3)

            // Tap hint
            if viewModel.isIdle {
                Text("tap to start")
                    .font(theme.currentFont.font(size: 7))
                    .foregroundColor(theme.colors.textSecondary.opacity(0.5))
            } else if viewModel.isPaused {
                Text("tap to resume")
                    .font(theme.currentFont.font(size: 7))
                    .foregroundColor(theme.colors.textSecondary.opacity(0.5))
            } else {
                Text(" ")
                    .font(theme.currentFont.font(size: 7))
            }
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onChange(of: viewModel.editableCountdownDuration) { _, _ in
            scrollAccumulator = 0
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
