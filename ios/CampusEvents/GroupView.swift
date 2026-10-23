import SwiftUI
import Photos
import Vision

struct GroupView: View {
    @Environment(\.dismiss) private var dismiss
    var eventID: UUID
    var body: some View { NavigationStack { GroupContent(eventID: eventID).toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } } } } }
}

struct GroupContent: View {
    @Environment(AppStore.self) private var store
    var eventID: UUID
    @State private var zoom = false
    @State private var message: String?
    @State private var detectedLink: URL?
    @State private var confirmLink = false
    var body: some View {
        ScrollView {
            if let event = store.event(eventID) {
                let admitted = [.confirmed, .checkedIn].contains(store.registration(eventID)?.status ?? .cancelled)
                let allowed = !event.group.membersOnly || admitted || event.hostID == store.profile.id
                if !allowed {
                    EmptyState(symbol: "lock", title: "报名成功后解锁活动群", subtitle: "通过报名后，即可在这里查看二维码和入群方式。")
                } else {
                    VStack(spacing: 23) {
                        Image(systemName: "person.2.fill").font(.system(size: 32)).foregroundStyle(Color.accentGreen).frame(width: 84, height: 84).background(Color.accentGreen.opacity(0.08), in: RoundedRectangle(cornerRadius: 25))
                        VStack(spacing: 9) { Text(event.group.name).font(.title2.bold()); Text(event.title).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center) }
                        if let data = event.group.imageData, let image = UIImage(data: data) {
                            Button { zoom = true } label: { Image(uiImage: image).resizable().scaledToFit().frame(maxWidth: 300, maxHeight: 350).clipShape(RoundedRectangle(cornerRadius: 17)) }.accessibilityLabel("查看群二维码大图")
                            Button { savePhoto(image) } label: { Label("保存群二维码", systemImage: "square.and.arrow.down").frame(maxWidth: .infinity) }.buttonStyle(.bordered).controlSize(.large)
                        }
                        if !event.group.notice.isEmpty { Text(event.group.notice).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center).textSelection(.enabled) }
                        if let url = EventRules.safeGroupURL(event.group.link) ?? detectedLink {
                            Button { confirmLink = true } label: { Label("打开群链接", systemImage: "arrow.up.right.square").frame(maxWidth: .infinity) }.buttonStyle(PrimaryButton())
                                .confirmationDialog("前往 \(url.host ?? "群链接")", isPresented: $confirmLink, titleVisibility: .visible) { Button("打开链接") { UIApplication.shared.open(url) { ok in if !ok { message = "未能打开群链接，请检查链接是否有效。" } } } }
                        }
                        Button { openPlatform(event.group.platform) } label: { Label("打开\(event.group.platform)", systemImage: "arrow.up.forward.app").frame(maxWidth: .infinity) }.buttonStyle(.bordered).controlSize(.large)
                        if !event.group.available { EmptyState(symbol: "qrcode", title: "主办方还未添加群信息", subtitle: "群二维码发布后会显示在这里。") }
                    }.padding(25)
                    .task(id: event.group.imageData) { detectedLink = detectHTTPS(event.group.imageData) }
                    .sheet(isPresented: $zoom) { NavigationStack { if let data = event.group.imageData, let image = UIImage(data: data) { ZoomImage(image: image).background(Color.black).ignoresSafeArea(edges: .bottom).toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { zoom = false } } } } }
                }
            }
        }.background(Color.paper).navigationTitle("活动群").navigationBarTitleDisplayMode(.inline)
        .alert("活动群", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("知道了", role: .cancel) { message = nil } } message: { Text(message ?? "") }
    }
    func openPlatform(_ platform: String) {
        let url = URL(string: platform == "QQ" ? "mqq://" : "weixin://")!
        guard UIApplication.shared.canOpenURL(url) else { message = "当前设备未安装\(platform)。可以先保存二维码，在安装\(platform)的手机上扫码入群。"; return }
        UIApplication.shared.open(url) { success in if !success { message = "暂时无法打开\(platform)，请先保存二维码。" } }
    }
    func savePhoto(_ image: UIImage) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else { Task { @MainActor in message = "请在系统设置中允许活动君添加照片，之后再保存二维码。" }; return }
            PHPhotoLibrary.shared().performChanges { PHAssetChangeRequest.creationRequestForAsset(from: image) } completionHandler: { success, _ in Task { @MainActor in message = success ? "二维码已保存到相册。打开微信或 QQ，使用扫一扫从相册选择即可。" : "图片保存失败，请稍后再试。" } }
        }
    }
    func detectHTTPS(_ data: Data?) -> URL? {
        guard let data, let image = UIImage(data: data)?.cgImage else { return nil }
        let request = VNDetectBarcodesRequest(); request.symbologies = [.qr]
        try? VNImageRequestHandler(cgImage: image).perform([request])
        return request.results?.compactMap { $0.payloadStringValue.flatMap(EventRules.safeGroupURL) }.first
    }
}

struct ZoomImage: UIViewRepresentable {
    let image: UIImage
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> UIScrollView {
        let scroll = UIScrollView(); scroll.delegate = context.coordinator; scroll.minimumZoomScale = 1; scroll.maximumZoomScale = 5
        let imageView = UIImageView(image: image); imageView.contentMode = .scaleAspectFit; imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scroll.addSubview(imageView); context.coordinator.imageView = imageView
        return scroll
    }
    func updateUIView(_ scroll: UIScrollView, context: Context) { context.coordinator.imageView?.frame = scroll.bounds }
    class Coordinator: NSObject, UIScrollViewDelegate {
        var imageView: UIImageView?
        func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }
    }
}
