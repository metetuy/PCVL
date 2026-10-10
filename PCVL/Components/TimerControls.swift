import SwiftUI
import AppKit

// Timer building blocks shared by the menu bar panel and the window's focus screen.
// `scale` = 1 is the compact panel size.

// MARK: - Pointer Cursor

private extension View {
    /// Tracks hover into `isHovering` and shows a pointing-hand cursor meanwhile.
    func pointerHover(_ isHovering: Binding<Bool>) -> some View {
        onHover { isHovering.wrappedValue = $0 }
            .pointerStyle(.link)
    }

    /// Raised look shared by the timer buttons: top highlight stroke + hover-lifted shadow.
    func raisedControl<S: Shape>(_ shape: S, isHovering: Bool) -> some View {
        self
            .overlay(
                shape.stroke(
                    LinearGradient(colors: [Color.white.opacity(0.16), .clear], startPoint: .top, endPoint: .bottom),
                    lineWidth: 1
                )
            )
            .shadow(
                color: .black.opacity(isHovering ? 0.30 : 0.24),
                radius: isHovering ? 9 : 3,
                x: 0,
                y: isHovering ? 3 : 1
            )
    }
}

// MARK: - Circle Button

/// Round icon button used beside the timer (reset, skip).
struct TimerCircleButton: View {
    let icon: String
    var iconSize: CGFloat = 11
    var scale: CGFloat = 1
    @ObservedObject var theme: ThemeManager
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(theme.currentFont.font(size: iconSize * scale, weight: .medium))
                .foregroundColor(theme.colors.textSecondary)
                .frame(width: 26 * scale, height: 26 * scale)
                .background(theme.colors.surface)
                .clipShape(Circle())
                .raisedControl(Circle(), isHovering: isHovering)
        }
        .buttonStyle(SpringButtonStyle(kind: .secondary, theme: theme))
        .scaleEffect(isHovering ? 1.05 : 1)
        .animation(.spring(response: 0.30, dampingFraction: 0.60), value: isHovering)
        .pointerHover($isHovering)
    }
}

// MARK: - Control Row

/// Reset | center | skip — the one control row shared by the panel and the focus
/// screen, so both apply the same reset and skip rules.
struct TimerControlRow<Center: View>: View {
    @ObservedObject var viewModel: TimerViewModel
    @ObservedObject var theme: ThemeManager
    var scale: CGFloat = 1
    var spacing: CGFloat = 12
    @ViewBuilder let center: () -> Center

    var body: some View {
        HStack(spacing: spacing) {
            TimerCircleButton(icon: "arrow.counterclockwise", scale: scale, theme: theme) {
                withAnimation(.easeInOut(duration: 0.15)) {
                    viewModel.reset()
                }
            }
            .disabled(viewModel.isIdle)
            .opacity(viewModel.isIdle ? 0.3 : 1)
            .help("Reset")

            center()

            TimerCircleButton(icon: "forward.end", iconSize: 10, scale: scale, theme: theme) {
                withAnimation(.easeInOut(duration: 0.15)) {
                    viewModel.skipPhase()
                }
            }
            .disabled(!viewModel.canSkipPhase)
            .opacity(viewModel.canSkipPhase ? 1 : 0.3)
            .help(viewModel.isBreak ? "Skip to focus" : "Skip to break")
        }
    }
}

// MARK: - Primary Button

/// Start / Pause / Resume / Skip capsule.
struct TimerPrimaryButton: View {
    @ObservedObject var viewModel: TimerViewModel
    @ObservedObject var theme: ThemeManager
    var scale: CGFloat = 1

    @State private var isHovering = false

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                viewModel.performPrimaryAction()
            }
        } label: {
            Text(viewModel.primaryActionLabel)
                .font(theme.currentFont.font(size: 11.5 * scale, weight: .semibold))
                .foregroundColor(viewModel.isRunning ? theme.colors.text : theme.colors.background)
                .frame(minWidth: 78 * scale, minHeight: 25 * scale)
                .padding(.horizontal, 15 * scale)
                .background(viewModel.isRunning ? theme.colors.text.opacity(0.12) : theme.colors.accent)
                .clipShape(Capsule())
                .raisedControl(Capsule(), isHovering: isHovering)
        }
        .buttonStyle(SpringButtonStyle(kind: .primary, theme: theme))
        .scaleEffect(isHovering ? 1.05 : 1)
        .animation(.spring(response: 0.30, dampingFraction: 0.60), value: isHovering)
        .pointerHover($isHovering)
    }
}

// MARK: - Mode Toggle

/// Timer / Stopwatch capsule switch; locked while a session is in progress.
struct TimerModeToggle: View {
    @ObservedObject var viewModel: TimerViewModel
    @ObservedObject var theme: ThemeManager
    var scale: CGFloat = 1

    @State private var hoveringMode: TimerMode?

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TimerMode.allCases, id: \.self) { mode in
                modeButton(mode)
            }
        }
        .padding(2 * scale)
        .background(theme.colors.surface)
        .clipShape(Capsule())
    }

    private func modeButton(_ mode: TimerMode) -> some View {
        let isSelected = viewModel.mode == mode
        let isHovering = hoveringMode == mode

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.mode = mode
            }
        } label: {
            Text(mode == .countDown ? "Timer" : "Stopwatch")
                .font(theme.currentFont.font(size: 9 * scale, weight: .medium))
                .foregroundColor(isSelected ? theme.colors.accent : theme.colors.textSecondary)
                .padding(.horizontal, 8 * scale)
                .padding(.vertical, 4 * scale)
                .background(isSelected ? theme.colors.accent.opacity(0.12) : Color.clear)
                .clipShape(Capsule())
                .modifier(SelectedRaise(isSelected: isSelected, isHovering: isHovering))
        }
        .buttonStyle(SpringButtonStyle(kind: .secondary, theme: theme))
        .disabled(!viewModel.isIdle)
        .opacity(viewModel.isIdle || isSelected ? 1 : 0.4)
        .scaleEffect(isHovering ? 1.05 : 1)
        .animation(.spring(response: 0.30, dampingFraction: 0.60), value: hoveringMode)
        .pointerHover(Binding(
            get: { hoveringMode == mode },
            set: { hovering in
                hoveringMode = hovering ? mode : (hoveringMode == mode ? nil : hoveringMode)
            }
        ))
    }

    /// Only the selected segment gets the raised look.
    private struct SelectedRaise: ViewModifier {
        let isSelected: Bool
        let isHovering: Bool

        func body(content: Content) -> some View {
            if isSelected {
                content.raisedControl(Capsule(), isHovering: isHovering)
            } else {
                content
            }
        }
    }
}

// MARK: - Progress Line

/// Left-to-right countdown progress; just the track in stopwatch mode.
struct TimerProgressLine: View {
    @ObservedObject var viewModel: TimerViewModel
    @ObservedObject var theme: ThemeManager
    var height: CGFloat = 3

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(theme.colors.ringTrack)

                if viewModel.mode == .countDown {
                    RoundedRectangle(cornerRadius: height / 2)
                        .fill(viewModel.isBreak ? theme.colors.breakRing : theme.colors.timerRing)
                        .frame(width: geo.size.width * viewModel.engine.progress)
                        .animation(.linear(duration: 0.3), value: viewModel.engine.progress)
                }
            }
        }
        .frame(height: height)
    }
}

// MARK: - Scroll to Adjust Duration

extension View {
    /// Scrolling over this view adjusts the countdown duration while idle
    /// (±5 min work, ±1 min break), with haptic ticks.
    func timerDurationScroll(_ viewModel: TimerViewModel) -> some View {
        modifier(TimerDurationScrollModifier(viewModel: viewModel))
    }
}

private struct TimerDurationScrollModifier: ViewModifier {
    @ObservedObject var viewModel: TimerViewModel

    @State private var accumulator: CGFloat = 0
    @State private var lastHapticTime: CFTimeInterval = 0

    func body(content: Content) -> some View {
        content
            .overlay {
                TimerScrollWheelMonitor(
                    isEnabled: viewModel.editableCountdownDuration != nil,
                    onScroll: handleScroll
                )
                .allowsHitTesting(false)
            }
            .onChange(of: viewModel.editableCountdownDuration) { _, _ in
                accumulator = 0
            }
    }

    private func handleScroll(_ deltaY: CGFloat) {
        guard let duration = viewModel.editableCountdownDuration else {
            accumulator = 0
            return
        }

        accumulator += deltaY

        while abs(accumulator) >= TimerScrollWheelMonitor.scrollThreshold {
            let direction = accumulator > 0 ? 1 : -1
            accumulator -= CGFloat(direction) * TimerScrollWheelMonitor.scrollThreshold
            viewModel.adjustDuration(duration, byMinutes: direction * duration.stepMinutes)

            // Haptics fire at most every 80ms during a fast scroll.
            let now = CFAbsoluteTimeGetCurrent()
            if now - lastHapticTime >= 0.08 {
                NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                lastHapticTime = now
            }
        }
    }
}

// MARK: - Scroll Wheel Monitor

/// Observes scroll events over its own bounds without swallowing them.
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
            // The panel and the window each host a monitor; only react in our own window.
            guard let view, let window = view.window, event.window === window else { return }

            let point = view.convert(event.locationInWindow, from: nil)
            guard view.bounds.contains(point) else { return }

            onScroll(-event.scrollingDeltaY)
        }
    }
}
