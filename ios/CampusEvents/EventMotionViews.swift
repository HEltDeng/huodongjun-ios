import SwiftUI

struct EventCardStack: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let events: [CampusEvent]
    var select: (CampusEvent) -> Void
    @State private var expanded = false
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("我的活动卡").font(.title3.bold()); Spacer()
                Button { withAnimation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.86)) { expanded.toggle() } } label: {
                    Label(expanded ? "收起" : "展开 \(events.count) 场", systemImage: expanded ? "rectangle.stack" : "rectangle.stack.fill").font(.caption.weight(.medium)).frame(minHeight: 44)
                }.buttonStyle(SoftPressStyle()).accessibilityIdentifier("activities.expand")
            }
            let layout = expanded ? AnyLayout(VStackLayout(spacing: 13)) : AnyLayout(ZStackLayout(alignment: .top))
            layout {
                ForEach(Array((expanded ? events : Array(events.prefix(3))).enumerated()), id: \.element.id) { index, event in
                    Button { select(event) } label: {
                        VStack(alignment: .leading, spacing: 9) {
                            EventRow(event: event)
                            HStack { if event.cancelled { Tag(text: "活动已取消", color: .red) } else if let reg = store.registration(event.id) { Tag(text: reg.status.rawValue) }; Spacer(); Label("查看活动", systemImage: "arrow.up.right").font(.caption).foregroundStyle(.secondary) }
                        }.padding(15).frame(maxWidth: .infinity, minHeight: 142).background(.white, in: RoundedRectangle(cornerRadius: 23)).overlay(RoundedRectangle(cornerRadius: 23).stroke(Color.accentGreen.opacity(0.055)))
                    }.buttonStyle(SoftPressStyle())
                        .scaleEffect(expanded ? 1 : 1 - Double(index) * 0.045, anchor: .top)
                        .offset(y: expanded ? 0 : CGFloat(index) * 15).zIndex(Double(events.count - index))
                        .animation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.86).delay(Double(index) * 0.035), value: expanded)
                        .allowsHitTesting(expanded || index == 0).accessibilityHidden(!expanded && index != 0)
                }
            }.padding(.bottom, expanded ? 0 : CGFloat(min(2, max(0, events.count - 1))) * 15)
        }.sensoryFeedback(.selection, trigger: expanded)
    }
}
struct ScheduleFocus: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let events: [CampusEvent]
    var select: (CampusEvent) -> Void
    @State private var focused: UUID?
    @State private var settled = true
    var current: CampusEvent? { events.first { $0.id == focused } ?? events.first }
    var body: some View {
        let motionDisabled = reduceMotion
        VStack(alignment: .leading, spacing: 14) {
            HStack { Text("日程聚焦").font(.title3.bold()); Spacer(); Text("上下滑动").font(.caption).foregroundStyle(.secondary) }
            HStack(spacing: 14) {
                VStack(spacing: 8) {
                    Image(systemName: "calendar").font(.title3).foregroundStyle(Color.accentGreen)
                    GeometryReader { geometry in
                        ZStack(alignment: .top) {
                            Capsule().fill(Color.accentGreen.opacity(0.1))
                            Capsule().fill(Color.accentGreen).frame(height: settled ? geometry.size.height : 0)
                        }.animation(reduceMotion ? nil : .easeOut(duration: 0.45), value: settled)
                    }.frame(width: 3)
                    Circle().fill(Color.accentGreen).frame(width: 8, height: 8)
                }.frame(width: 24).accessibilityHidden(true)
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 16) {
                        ForEach(events) { event in
                            Button { select(event) } label: {
                                VStack(alignment: .leading, spacing: 14) {
                                    Text(event.start.formatted(.dateTime.month().day().weekday())).font(.caption.weight(.semibold)).foregroundStyle(Color.accentGreen)
                                    EventCover(event: event).frame(height: 135).clipped().clipShape(RoundedRectangle(cornerRadius: 17))
                                    Text(event.title).font(.headline).lineLimit(2).multilineTextAlignment(.leading)
                                    Label(event.location, systemImage: "mappin").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                }.padding(16).frame(maxWidth: .infinity, alignment: .leading).frame(height: 280).background(.white, in: RoundedRectangle(cornerRadius: 23))
                            }.buttonStyle(SoftPressStyle()).id(event.id)
                                .scrollTransition(.interactive, axis: .vertical) { content, phase in content.opacity(phase.isIdentity ? 1 : 0.5).scaleEffect(motionDisabled || phase.isIdentity ? 1 : 0.96) }
                        }
                    }.scrollTargetLayout()
                }.frame(height: 280).scrollTargetBehavior(.viewAligned(limitBehavior: .always)).scrollPosition(id: $focused, anchor: .center)
                    .onScrollPhaseChange { _, phase in settled = phase == .idle }
            }
            if let current { Text(current.start.formatted(.dateTime.hour().minute()) + " · " + current.title).font(.caption).foregroundStyle(.secondary).lineLimit(1).padding(.leading, 38) }
        }.accessibilityHint("上下滑动切换日程，轻点卡片查看详情")
    }
}
