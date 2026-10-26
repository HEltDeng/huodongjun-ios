import SwiftUI

private struct RadialReveal: Shape {
    var progress: CGFloat
    var x: CGFloat
    var animatableData: CGFloat { get { progress } set { progress = newValue } }
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.width * x, y: rect.height)
        let radius = hypot(max(center.x, rect.width - center.x), rect.height) * max(0.001, progress)
        return Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }
}
struct NavigationShell: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var tab = 0
    @State private var previous = 0
    @State private var progress: CGFloat = 1
    @State private var transitionTask: Task<Void, Never>?
    @State private var create = false
    @State private var guide = false
    @State private var guideStep = 0
    @Namespace private var navSelection
    private let titles = ["发现", "活动", "消息", "我的"]
    private let icons = ["sparkles", "calendar", "bubble.left.and.bubble.right", "person.crop.circle"]
    private let positions: [CGFloat] = [0.14, 0.32, 0.68, 0.86]
    var body: some View {
        VStack(spacing: 0) {
        ZStack {
            ForEach(0..<4) { index in
                page(index).background(Color.paper)
                    .mask(RadialReveal(progress: index == tab ? progress : 1, x: positions[tab]))
                    .opacity(index == tab || index == previous ? 1 : 0)
                    .zIndex(index == tab ? 1 : 0).allowsHitTesting(index == tab)
                    .accessibilityHidden(index != tab)
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity).clipped()
            VStack(spacing: 0) {
                Color.clear.frame(height: 0).snackBar()
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 5), spacing: 0) {
                    navButton(0); navButton(1)
                    Button { create = true } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "plus").font(.system(size: 23, weight: .medium)).foregroundStyle(.white)
                                .frame(width: 44, height: 44).background(Color.ink, in: RoundedRectangle(cornerRadius: 15))
                            Text("发布").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.ink)
                        }.frame(maxWidth: .infinity).frame(height: 68).contentShape(Rectangle())
                    }.buttonStyle(SoftPressStyle()).accessibilityLabel("发布活动").accessibilityIdentifier("nav.create").anchorPreference(key: NavAnchors.self, value: .bounds) { [4: $0] }
                    navButton(2); navButton(3)
                }.animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.85), value: tab)
                    .padding(5).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 26))
                    .overlay(RoundedRectangle(cornerRadius: 26).stroke(.white.opacity(0.85), lineWidth: 1))
                    .shadow(color: Color.ink.opacity(0.06), radius: 12, y: 4).padding(.horizontal, 16).padding(.top, 5).padding(.bottom, 6)

            }
        }.background(Color.paper).sheet(isPresented: $create) { EventEditorView().appSheet(.large, stops: [SheetSize.tall, .large]) }
            .overlayPreferenceValue(NavAnchors.self) { anchors in
                if guide { GeometryReader { geometry in
                    if let anchor = anchors[guideStep == 0 ? 0 : guideStep == 1 ? 4 : 2] { tour(focus: geometry[anchor].insetBy(dx: -3, dy: -3), clearance: geometry.size.height - geometry[anchor].minY + 18) }
                }.ignoresSafeArea() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .openMyActivities)) { _ in select(1) }
            .onReceive(NotificationCenter.default.publisher(for: .showInteractionTour)) { _ in guideStep = 0; guide = true }
            .onAppear { if store.state.settings.interactionTourSeen != true { guideStep = 0; guide = true } }
            .onChange(of: store.contextID) { _, _ in store.snack = nil }
            .onDisappear { transitionTask?.cancel() }
    }
    @ViewBuilder func page(_ index: Int) -> some View {
        switch index { case 0: DiscoverView(); case 1: MyEventsView(); case 2: NoticesView(); default: ProfileView() }
    }
    func navButton(_ index: Int) -> some View {
        Button { select(index) } label: {
            VStack(spacing: 4) {
                Image(systemName: icons[index]).font(.system(size: 24, weight: .regular)).frame(width: 44, height: 44).symbolEffect(.bounce, value: reduceMotion ? false : tab == index)
                    .overlay(alignment: .topTrailing) { if index == 2 && store.unread > 0 { Circle().fill(Color.orange).frame(width: 7, height: 7).offset(x: -3, y: 5) } }
                Text(titles[index]).font(.system(size: 12, weight: tab == index ? .semibold : .medium))
            }.frame(maxWidth: .infinity).frame(height: 68).contentShape(Rectangle()).foregroundStyle(tab == index ? Color.accentGreen : Color.secondary)
                .background { if tab == index { RoundedRectangle(cornerRadius: 21).fill(Color.accentGreen.opacity(0.085)).matchedGeometryEffect(id: "nav", in: navSelection) } }
        }.buttonStyle(SoftPressStyle()).accessibilityAddTraits(tab == index ? .isSelected : [])
            .anchorPreference(key: NavAnchors.self, value: .bounds) { [index: $0] }
            .accessibilityIdentifier("nav.\(index)").accessibilityLabel(titles[index] + (index == 2 && store.unread > 0 ? "，\(store.unread)条未读" : ""))
    }
    func select(_ index: Int) {
        guard index != tab else { return }
        transitionTask?.cancel()
        previous = tab; tab = index; progress = reduceMotion ? 1 : 0
        transitionTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(20)); guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.42)) { progress = 1 }
            try? await Task.sleep(for: .milliseconds(450)); guard !Task.isCancelled else { return }; previous = tab
        }
    }
    func tour(focus: CGRect, clearance: CGFloat) -> some View {
            ZStack(alignment: .bottom) {
                Color.black.opacity(0.55).mask { SpotlightCutout(rect: focus).fill(style: FillStyle(eoFill: true)) }.contentShape(Rectangle()).onTapGesture {}
                VStack(alignment: .leading, spacing: 14) {
                    HStack { Text("\(guideStep + 1) / 3").font(.caption.monospaced()).foregroundStyle(Color.accentGreen); Spacer(); Button("跳过引导") { finishTour() }.font(.caption).frame(minHeight: 44) }
                    Text(["常用操作，就在手边", "把想法变成一场相聚", "每一次参与都有回应"][guideStep]).font(.title3.bold())
                    Text(["发现页底部可以切换空间、搜索、选择兴趣和筛选。面板上拉展开，下拉收起。", "点底部加号创建活动。先选空间和报名学校，再预览发布。", "报名通知和活动讨论在消息中查看。收藏和关注可在底部提示条里撤销。"][guideStep]).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Button(guideStep == 2 ? "开始体验" : "下一步") { if guideStep == 2 { finishTour() } else { withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { guideStep += 1 } } }.buttonStyle(QuietButton())
                }.padding(22).background(Color.paper, in: RoundedRectangle(cornerRadius: 25)).padding(.horizontal, 22).padding(.bottom, clearance)
            }.accessibilityElement(children: .contain).accessibilityAddTraits(.isModal)
    }
    func finishTour() { guide = false; store.update { $0.settings.interactionTourSeen = true } }
}
private struct SpotlightCutout: Shape {
    let rect: CGRect
    func path(in bounds: CGRect) -> Path { var path = Path(bounds); path.addRoundedRect(in: rect, cornerSize: CGSize(width: 20, height: 20)); return path }
}
extension Notification.Name { static let showInteractionTour = Notification.Name("showInteractionTour"); static let openMyActivities = Notification.Name("openMyActivities") }

private struct NavAnchors: PreferenceKey {
    static var defaultValue: [Int: Anchor<CGRect>] = [:]
    static func reduce(value: inout [Int: Anchor<CGRect>], nextValue: () -> [Int: Anchor<CGRect>]) { value.merge(nextValue(), uniquingKeysWith: { _, latest in latest }) }
}
