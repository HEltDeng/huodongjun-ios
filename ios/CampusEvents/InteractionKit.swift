import SwiftUI
import Observation

// Fractions use the system's available presentation height, including safe-area handling.
enum SheetSize {
    static let peek = PresentationDetent.fraction(0.3)
    static let half = PresentationDetent.fraction(0.6)
    static let tall = PresentationDetent.fraction(0.8)
}
struct AppSheetStyle: ViewModifier {
    var initial: PresentationDetent
    var stops: Set<PresentationDetent>
    @State private var selection: PresentationDetent
    init(initial: PresentationDetent, stops: Set<PresentationDetent>) {
        self.initial = initial; self.stops = stops
        _selection = State(initialValue: initial)
    }
    func body(content: Content) -> some View {
        content.presentationDetents(stops, selection: $selection)
            .presentationDragIndicator(.visible).presentationCornerRadius(30)
            .presentationContentInteraction(.resizes).presentationBackground(Color.paper)
            .snackBar()
    }
}
extension View {
    func appSheet(_ initial: PresentationDetent = SheetSize.tall, stops: Set<PresentationDetent> = [SheetSize.half, SheetSize.tall, .large]) -> some View {
        modifier(AppSheetStyle(initial: initial, stops: stops))
    }
    func bottomDismiss(_ title: String = "完成") -> some View { modifier(BottomDismiss(title: title)) }
    func snackBar() -> some View { modifier(SnackBarHost()) }
}
struct BottomDismiss: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    var title: String
    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom, spacing: 0) {
            Button(title) { dismiss() }.buttonStyle(QuietButton()).padding(.horizontal, 22).padding(.vertical, 10).background(.regularMaterial)
        }
    }
}
struct QuietButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 46)
            .foregroundStyle(Color.ink).background(Color.accentGreen.opacity(configuration.isPressed ? 0.13 : 0.06), in: RoundedRectangle(cornerRadius: 15))
    }
}
struct InlineAlert: View {
    let message: String?
    var body: some View {
        if let message {
            Label(message, systemImage: "exclamationmark.circle.fill").font(.caption).foregroundStyle(Color.red)
                .fixedSize(horizontal: false, vertical: true).accessibilityLabel("错误：" + message)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 3)
        }
    }
}
struct SnackNotice: Identifiable {
    let id = UUID()
    let message: String
    var undo: (() -> Void)? = nil
}
struct SnackBarHost: ViewModifier {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    func body(content: Content) -> some View {
        VStack(spacing: 0) {
            content
            if let snack = store.snack {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.mint)
                    Text(snack.message).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    if let undo = snack.undo {
                        Button("撤销") { store.snack = nil; undo() }.font(.subheadline.bold()).foregroundStyle(Color.mint).frame(minWidth: 44, minHeight: 44).accessibilityIdentifier("snack.undo")
                    }
                    Button { store.dismissSnack(snack.id) } label: { Image(systemName: "xmark").font(.caption.bold()).frame(width: 36, height: 44) }.accessibilityLabel("关闭提示")
                }.foregroundStyle(.white).padding(.leading, 17).padding(.trailing, 7).padding(.vertical, 5)
                    .background(Color.ink, in: RoundedRectangle(cornerRadius: 18)).shadow(color: .black.opacity(0.12), radius: 15, y: 5)
                    .padding(.horizontal, 18).padding(.vertical, 8).transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                    .task(id: snack.id) {
                        // VoiceOver users retain the undo opportunity until they dismiss it.
                        guard !voiceOver else { return }
                        try? await Task.sleep(for: .seconds(snack.undo == nil ? 4 : 8))
                        if !Task.isCancelled { store.dismissSnack(snack.id) }
                    }
            }
        }.animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.88), value: store.snack?.id)
    }
}
struct DrawnCheck: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path(); p.move(to: CGPoint(x: rect.width * 0.18, y: rect.height * 0.51))
        p.addLine(to: CGPoint(x: rect.width * 0.41, y: rect.height * 0.75)); p.addLine(to: CGPoint(x: rect.width * 0.82, y: rect.height * 0.25))
        return p
    }
}
struct CompletionButton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var enabled
    var title: String
    var symbol = "checkmark"
    var action: () -> Bool
    var completed: () -> Void = {}
    @State private var phase = 0
    @State private var drawn = false
    @State private var busyTask: Task<Void, Never>?
    var body: some View {
        GeometryReader { geometry in
            Button {
                guard phase == 0 else { return }
                phase = 1
                busyTask = Task { @MainActor in
                    await Task.yield()
                    guard action() else { phase = 0; return }
                    withAnimation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.8)) { phase = 2 }
                    try? await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 80))
                    guard !Task.isCancelled else { return }
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.35)) { drawn = true }
                    try? await Task.sleep(for: .milliseconds(reduceMotion ? 180 : 680))
                    guard !Task.isCancelled else { return }
                    completed(); phase = 0; drawn = false
                }
            } label: {
                ZStack {
                    if phase == 2 {
                        DrawnCheck().trim(from: 0, to: drawn ? 1 : 0).stroke(.white, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)).frame(width: 27, height: 27)
                        if !reduceMotion { ForEach(0..<8) { n in
                            Circle().fill(Color.accentGreen).frame(width: 4, height: 4).offset(y: drawn ? -37 : -12).rotationEffect(.degrees(Double(n) * 45)).opacity(drawn ? 0 : 1)
                        } }
                    } else if phase == 1 { ProgressView().tint(.white) }
                    else { Label(title, systemImage: symbol).font(.system(size: 16, weight: .semibold)) }
                }.foregroundStyle(.white).frame(width: phase == 2 ? 54 : geometry.size.width, height: 54)
                    .background(enabled ? (phase == 2 ? Color.accentGreen : Color.ink) : .gray.opacity(0.4), in: RoundedRectangle(cornerRadius: phase == 2 ? 27 : 17))
                    .frame(maxWidth: .infinity)
            }.buttonStyle(SoftPressStyle()).disabled(phase != 0)
                .accessibilityLabel(phase == 2 ? "已完成" : phase == 1 ? "正在处理" : title)
        }.frame(height: 54).sensoryFeedback(.success, trigger: phase) { _, newValue in newValue == 2 }
            .onDisappear { busyTask?.cancel() }
    }
}
struct ProgressOrbit: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var count: Int
    var total: Int
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().stroke(Color.accentGreen.opacity(0.1), lineWidth: 5)
                Circle().trim(from: 0, to: min(1, CGFloat(count) / CGFloat(max(1, total)))).stroke(Color.accentGreen, style: StrokeStyle(lineWidth: 5, lineCap: .round)).rotationEffect(.degrees(-90))
                Text(count, format: .number).font(.system(size: 20, weight: .semibold, design: .rounded)).contentTransition(.numericText())
            }.frame(width: 53, height: 53).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(count == 0 ? "让好活动更懂你" : "已找到 \(count) 个兴趣方向").font(.subheadline.weight(.semibold)).contentTransition(.numericText())
                Text("按你的喜好，遇见下一场相聚").font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }.padding(17).background(Color.accentGreen.opacity(0.035 + Double(count) * 0.005), in: RoundedRectangle(cornerRadius: 20))
            .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85), value: count)
            .accessibilityElement(children: .ignore).accessibilityLabel("已选择 \(count) 个兴趣方向")
    }
}
struct DateWheelSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    @Binding var value: Date
    var lower: Date = .distantPast
    var upper: Date = .distantFuture
    var dateOnly = false
    @State private var draft = Date()
    var body: some View {
        VStack(spacing: 18) {
            HStack { Text(title).font(.title3.bold()); Spacer(); Image(systemName: "calendar").foregroundStyle(Color.accentGreen) }.padding(.top, 26)
            DatePicker(title, selection: $draft, in: lower...max(lower, upper), displayedComponents: dateOnly ? [.date] : [.date, .hourAndMinute])
                .datePickerStyle(.wheel).labelsHidden().frame(maxWidth: .infinity)
            Button { value = draft; dismiss() } label: { Text("使用这个时间").frame(maxWidth: .infinity) }.buttonStyle(PrimaryButton())
            Button("取消") { dismiss() }.buttonStyle(QuietButton())
        }.padding(.horizontal, 22).padding(.bottom, 15).onAppear { draft = min(max(value, lower), upper) }
    }
}
struct DateWheelRow: View {
    let title: String
    @Binding var value: Date
    var lower: Date = .distantPast
    var upper: Date = .distantFuture
    var dateOnly = false
    @State private var presented = false
    var body: some View {
        Button { presented = true } label: {
            HStack { Text(title).foregroundStyle(.primary); Spacer(); Text(value.formatted(date: .abbreviated, time: dateOnly ? .omitted : .shortened)).font(.subheadline).foregroundStyle(Color.accentGreen); Image(systemName: "chevron.up.chevron.down").font(.caption2).foregroundStyle(.secondary) }.frame(minHeight: 34)
        }.buttonStyle(SoftPressStyle()).sheet(isPresented: $presented) { DateWheelSheet(title: title, value: $value, lower: lower, upper: upper, dateOnly: dateOnly).appSheet(SheetSize.half, stops: [SheetSize.half, SheetSize.tall, .large]) }
    }
}

// A deliberate decision: no backdrop tap, swipe or Escape dismissal.
struct BlockingDecision: View {
    let title: String
    let message: String
    let destructiveTitle: String
    var failure: String?
    let cancel: () -> Void
    let confirm: () -> Void
    var body: some View {
        ZStack {
            Color.black.opacity(0.48).ignoresSafeArea().contentShape(Rectangle()).onTapGesture {}
            VStack(spacing: 18) {
                Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 28)).foregroundStyle(.red).padding(16).background(.red.opacity(0.07), in: Circle())
                Text(title).font(.title3.bold()).multilineTextAlignment(.center)
                Text(message).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                InlineAlert(message: failure)
                Button(role: .destructive, action: confirm) { Text(destructiveTitle).font(.subheadline.bold()).frame(maxWidth: .infinity, minHeight: 52).foregroundStyle(.white).background(.red, in: RoundedRectangle(cornerRadius: 15)) }.buttonStyle(SoftPressStyle())
                Button("保留活动", action: cancel).buttonStyle(QuietButton())
            }.padding(24).frame(maxWidth: 350).background(Color.paper, in: RoundedRectangle(cornerRadius: 28)).padding(22)
        }.interactiveDismissDisabled().background(EscapeBlocker()).accessibilityAddTraits(.isModal)
    }
}
private struct EscapeBlocker: UIViewRepresentable {
    func makeUIView(context: Context) -> KeyView { let view = KeyView(); DispatchQueue.main.async { view.becomeFirstResponder() }; return view }
    func updateUIView(_ uiView: KeyView, context: Context) {}
    final class KeyView: UIView {
        override var canBecomeFirstResponder: Bool { true }
        override var keyCommands: [UIKeyCommand]? {
            let escape = UIKeyCommand(input: UIKeyCommand.inputEscape, modifierFlags: [], action: #selector(ignoreEscape))
            escape.wantsPriorityOverSystemBehavior = true
            return [escape]
        }
        @objc private func ignoreEscape() {}
    }
}

struct SheetAction: Identifiable {
    var id: String { title }
    let title: String
    var role: ButtonRole?
    let perform: () -> Void
    init(_ title: String, role: ButtonRole? = nil, perform: @escaping () -> Void) {
        self.title = title; self.role = role; self.perform = perform
    }
}
private struct BottomActions: ViewModifier {
    let title: String
    @Binding var presented: Bool
    let actions: [SheetAction]
    var cancelTitle: String
    @State private var pending: (() -> Void)?
    func body(content: Content) -> some View {
        content.sheet(isPresented: $presented, onDismiss: {
            let action = pending; pending = nil; action?()
        }) {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 12) {
                        Text(title).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true).padding(.horizontal, 12)
                        VStack(spacing: 0) {
                            ForEach(actions) { item in
                                Button(role: item.role) { pending = item.perform; presented = false } label: {
                                    Text(item.title).font(.system(size: 17, weight: .medium)).foregroundStyle(item.role == .destructive ? Color.red : Color.ink).frame(maxWidth: .infinity, minHeight: 48).contentShape(Rectangle())
                                }.buttonStyle(SoftPressStyle())
                                if item.id != actions.last?.id { Divider().padding(.horizontal, 18) }
                            }
                        }.background(.white, in: RoundedRectangle(cornerRadius: 18))
                    }.padding(.horizontal, 18).padding(.top, 24).padding(.bottom, 8)
                }.scrollBounceBehavior(.basedOnSize)
                Button { pending = nil; presented = false } label: {
                    Text(cancelTitle).font(.system(size: 17, weight: .semibold)).frame(maxWidth: .infinity, minHeight: 48)
                        .background(.white, in: RoundedRectangle(cornerRadius: 18)).contentShape(Rectangle())
                }.buttonStyle(SoftPressStyle()).padding(.horizontal, 18).padding(.top, 5).padding(.bottom, 12)
            }.appSheet(actions.count > 2 ? SheetSize.half : SheetSize.peek, stops: [SheetSize.peek, SheetSize.half, SheetSize.tall])
        }
    }
}
extension View {
    func bottomActions(_ title: String, isPresented: Binding<Bool>, cancelTitle: String = "取消", actions: [SheetAction]) -> some View {
        modifier(BottomActions(title: title, presented: isPresented, actions: actions, cancelTitle: cancelTitle))
    }
}
