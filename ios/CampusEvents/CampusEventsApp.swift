import SwiftUI

@main
struct CampusEventsApp: App {
    @State private var store = AppStore()
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .tint(.primary)
                .environment(\.locale, Locale(identifier: "zh_CN"))
                .environment(\.timeZone, TimeZone(identifier: "Asia/Shanghai")!)
                .preferredColorScheme(.light)
        }
    }
}

struct RootView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        @Bindable var store = store
        Group {
            if store.state.onboarded && !store.state.settings.setupCompleted {
                SpaceOnboardingView()
            } else if store.state.onboarded {
                NavigationShell()
            } else { WelcomeView() }
        }
        .alert("暂时无法完成", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
            Button("知道了", role: .cancel) { store.error = nil }
        } message: { Text(store.error ?? "") }
    }
}

struct WelcomeView: View {
    @Environment(AppStore.self) private var store
    @State private var consent = false
    @State private var service = false
    @State private var onboarding = false
    var body: some View {
        VStack(spacing: 0) {
            HStack { Label("校园 · 长沙", systemImage: "building.columns").font(.subheadline.weight(.medium)); Spacer(); Text("MEET HERE").font(.caption.monospaced()).foregroundStyle(.secondary) }.padding(26)
            Spacer(minLength: 16)
            ZStack {
                Image("music").resizable().scaledToFill().frame(width: 146, height: 146).clipped().clipShape(RoundedRectangle(cornerRadius: 22)).rotationEffect(.degrees(-14)).offset(x: -92, y: -20)
                Image("tech").resizable().scaledToFill().frame(width: 146, height: 146).clipped().clipShape(RoundedRectangle(cornerRadius: 22)).rotationEffect(.degrees(13)).offset(x: 92, y: -20)
                Image("weekend").resizable().scaledToFill().frame(width: 185, height: 185).clipped().clipShape(RoundedRectangle(cornerRadius: 25)).rotationEffect(.degrees(-3)).offset(y: 54).shadow(color: .black.opacity(0.12), radius: 18, y: 14)
            }.frame(height: 265).accessibilityHidden(true)
            Spacer(minLength: 25)
            VStack(spacing: 14) {
                Text("活动君").font(.system(size: 38, weight: .bold, design: .rounded))
                Text("校园里，好事正在发生。").font(.title3).foregroundStyle(.secondary)
            }
            Spacer(minLength: 35)
            VStack(spacing: 17) {
                Button { onboarding = true } label: { Text("开始体验").frame(maxWidth: .infinity) }.buttonStyle(PrimaryButton()).disabled(!consent).accessibilityIdentifier("welcome.start")
                Button("先逛逛") { store.enter(consent: false) }.font(.subheadline.weight(.medium)).accessibilityIdentifier("welcome.browse")
                HStack(alignment: .center, spacing: 8) {
                    Button { consent.toggle() } label: { Image(systemName: consent ? "checkmark.square.fill" : "square").font(.title3).foregroundStyle(consent ? Color.ink : .secondary) }.accessibilityLabel("同意服务说明").accessibilityValue(consent ? "已选中" : "未选中").accessibilityIdentifier("welcome.consent")
                    Text("我已阅读并同意").font(.caption).foregroundStyle(.secondary)
                    Button("服务说明与隐私") { service = true }.font(.caption)
                }.padding(.top, 5)
            }.padding(.horizontal, 28).padding(.bottom, 24)
        }.background(Color.paper)
        .sheet(isPresented: $service) { ServiceInfoView().appSheet() }
        .sheet(isPresented: $onboarding) { IdentityEditor(isOnboarding: true).appSheet() }
    }
}

extension Color {
    static let paper = Color(red: 0.985, green: 0.981, blue: 0.966)
    static let ink = Color(red: 0.10, green: 0.14, blue: 0.12)
    static let accentGreen = Color(red: 0.24, green: 0.40, blue: 0.29)
}
struct PrimaryButton: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 16, weight: .semibold)).foregroundStyle(.white).padding(.vertical, 17).padding(.horizontal, 22)
            .background(enabled ? Color.ink : Color.gray.opacity(0.35), in: RoundedRectangle(cornerRadius: 17)).opacity(configuration.isPressed ? 0.85 : 1).scaleEffect(configuration.isPressed && !reduceMotion ? 0.975 : 1).animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.78), value: configuration.isPressed)
    }
}
struct EventCover: View {
    var event: CampusEvent
    var body: some View {
        Group {
            if let data = event.imageData, let image = UIImage(data: data) { Image(uiImage: image).resizable() }
            else { Image(event.cover).resizable() }
        }.scaledToFill().accessibilityLabel(event.title + "活动海报")
    }
}
struct HostAvatar: View {
    var name: String
    var size: CGFloat = 34
    var body: some View {
        Text(String(name.prefix(1))).font(.system(size: size * 0.43, weight: .semibold)).foregroundStyle(Color.accentGreen).frame(width: size, height: size).background(Color.accentGreen.opacity(0.1), in: RoundedRectangle(cornerRadius: size * 0.3)).accessibilityHidden(true)
    }
}
struct Tag: View {
    var text: String
    var color: Color = .accentGreen
    var body: some View { Text(text).font(.caption2.weight(.semibold)).foregroundStyle(color).padding(.horizontal, 8).padding(.vertical, 5).background(color.opacity(0.09), in: Capsule()) }
}
struct EmptyState: View {
    var symbol: String
    var title: String
    var subtitle: String
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: symbol).font(.system(size: 36, weight: .light)).foregroundStyle(Color.accentGreen).frame(width: 84, height: 84).background(Color.accentGreen.opacity(0.07), in: RoundedRectangle(cornerRadius: 26))
            Text(title).font(.headline)
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(.vertical, 60).padding(.horizontal, 28)
    }
}
struct EventRow: View {
    @Environment(AppStore.self) private var store
    var event: CampusEvent
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            EventCover(event: event).frame(width: 92, height: 102).clipped().clipShape(RoundedRectangle(cornerRadius: 15))
            VStack(alignment: .leading, spacing: 7) {
                Text(event.start.formatted(.dateTime.month(.twoDigits).day(.twoDigits).weekday(.abbreviated).hour().minute())).font(.caption.weight(.medium)).foregroundStyle(Color.accentGreen)
                Text(event.title).font(.system(size: 16, weight: .semibold)).foregroundStyle(.primary).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                Label(event.location, systemImage: "mappin").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                HStack(spacing: 5) { Text(event.host).font(.caption2).foregroundStyle(.secondary).lineLimit(1); Spacer(minLength: 0); if event.space == .campus && event.creditHundredths > 0 { Tag(text: "+\(event.creditText) 综测") } }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }.padding(.vertical, 7).contentShape(Rectangle())
    }
}
