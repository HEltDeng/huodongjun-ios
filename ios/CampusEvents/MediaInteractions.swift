import SwiftUI
import PhotosUI
import AVFoundation

struct MediaPickerButton<Label: View>: View {
    @Environment(AppStore.self) private var store
    @Binding var data: Data?
    var png = false
    @ViewBuilder var label: () -> Label
    @State private var actions = false
    @State private var library = false
    @State private var camera = false
    @State private var preview = false
    @State private var selection: PhotosPickerItem?
    @State private var message: String?
    @State private var loading = false
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Button { actions = true } label: { label().overlay { if loading { ProgressView().padding(9).background(.regularMaterial, in: Circle()) } } }
                .buttonStyle(SoftPressStyle()).disabled(loading)
                .bottomActions("图片操作", isPresented: $actions, actions: imageActions)
                .photosPicker(isPresented: $library, selection: $selection, matching: .images)
                .fullScreenCover(isPresented: $camera) { CameraCapture { image in camera = false; if let image { setImage(image) } }.ignoresSafeArea() }
                .fullScreenCover(isPresented: $preview) { if let data, let image = UIImage(data: data) { MediaLightbox(image: image) } }
                .onChange(of: selection) { _, item in
                    Task { @MainActor in
                        loading = true; defer { loading = false }
                        do {
                            guard let bytes = try await item?.loadTransferable(type: Data.self), bytes.count <= 25_000_000, let image = UIImage(data: bytes) else { message = "请选择小于 25 MB 的有效图片。"; return }
                            setImage(image)
                        } catch { message = "图片读取失败，请重新选择。" }
                    }
                }
            InlineAlert(message: message)
        }
    }
    var imageActions: [SheetAction] {
        var items = [SheetAction]()
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            items.append(SheetAction("拍照") { Task { @MainActor in
                if await AVCaptureDevice.requestAccess(for: .video) { camera = true }
                else { message = "相机权限未开启，请在系统设置中允许，或从相册选择。" }
            } })
        }
        items.append(SheetAction("从相册选择") { library = true })
        if data != nil {
            items.append(SheetAction("查看大图") { preview = true })
            items.append(SheetAction("移除图片", role: .destructive) {
                let previous = data; data = nil
                store.notify("已移除图片") { data = previous; store.notify("已恢复图片") }
            })
        }
        return items
    }
    func setImage(_ image: UIImage) {
        let scale = min(1, 1600 / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
        let normalized = UIGraphicsImageRenderer(size: size, format: format).image { context in UIColor.white.setFill(); context.fill(CGRect(origin: .zero, size: size)); image.draw(in: CGRect(origin: .zero, size: size)) }
        data = png ? normalized.pngData() : normalized.jpegData(compressionQuality: 0.85); message = nil
    }
}
struct CameraCapture: UIViewControllerRepresentable {
    var selected: (UIImage?) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(selected: selected) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController(); picker.sourceType = .camera; picker.delegate = context.coordinator; return picker
    }
    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let selected: (UIImage?) -> Void
        init(selected: @escaping (UIImage?) -> Void) { self.selected = selected }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { selected(nil) }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) { selected(info[.originalImage] as? UIImage) }
    }
}
struct MediaLightbox: View {
    @Environment(\.dismiss) private var dismiss
    let image: UIImage
    @State private var zoom: CGFloat = 1
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ZoomableMedia(image: image, zoom: $zoom).ignoresSafeArea(edges: .top)
        }.safeAreaInset(edge: .bottom) {
            HStack(spacing: 20) {
                Button { zoom = max(1, zoom - 1) } label: { Image(systemName: "minus.magnifyingglass").frame(width: 44, height: 44) }.accessibilityLabel("缩小")
                Button { zoom = 1 } label: { Text("\(Int(zoom * 100))%").font(.caption.monospaced()).frame(minWidth: 50, minHeight: 44) }.accessibilityLabel("恢复原始大小")
                Button { zoom = min(5, zoom + 1) } label: { Image(systemName: "plus.magnifyingglass").frame(width: 44, height: 44) }.accessibilityLabel("放大")
                Spacer()
                Button("完成") { dismiss() }.font(.subheadline.bold()).frame(minWidth: 54, minHeight: 44)
            }.foregroundStyle(.white).padding(.horizontal, 22).padding(.vertical, 10).background(.black.opacity(0.8))
        }.statusBarHidden().accessibilityAction(.escape) { dismiss() }
    }
}
struct ZoomableMedia: UIViewRepresentable {
    var image: UIImage
    @Binding var zoom: CGFloat
    func makeCoordinator() -> Coordinator { Coordinator(zoom: $zoom) }
    func makeUIView(context: Context) -> UIScrollView {
        let scroll = MediaScrollView(); scroll.minimumZoomScale = 1; scroll.maximumZoomScale = 5; scroll.bouncesZoom = true
        scroll.backgroundColor = .black; scroll.delegate = context.coordinator; scroll.showsVerticalScrollIndicator = false; scroll.showsHorizontalScrollIndicator = false
        let imageView = UIImageView(image: image); imageView.contentMode = .scaleAspectFit; imageView.isUserInteractionEnabled = true
        scroll.addSubview(imageView); scroll.media = imageView; context.coordinator.imageView = imageView
        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.doubleTap(_:))); doubleTap.numberOfTapsRequired = 2; scroll.addGestureRecognizer(doubleTap)
        let wheel = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.wheel(_:))); wheel.allowedScrollTypesMask = .all; wheel.allowedTouchTypes = []; scroll.addGestureRecognizer(wheel)
        return scroll
    }
    func updateUIView(_ scroll: UIScrollView, context: Context) {
        context.coordinator.zoom = $zoom
        if abs(scroll.zoomScale - zoom) > 0.02, !scroll.isZooming { scroll.setZoomScale(zoom, animated: !UIAccessibility.isReduceMotionEnabled) }
    }
    class Coordinator: NSObject, UIScrollViewDelegate {
        var zoom: Binding<CGFloat>
        var imageView: UIImageView?
        init(zoom: Binding<CGFloat>) { self.zoom = zoom }
        func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }
        func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) { zoom.wrappedValue = scale }
        @objc func doubleTap(_ recognizer: UITapGestureRecognizer) {
            guard let scroll = recognizer.view as? UIScrollView else { return }
            scroll.setZoomScale(scroll.zoomScale > 1.1 ? 1 : 2.5, animated: !UIAccessibility.isReduceMotionEnabled)
        }
        @objc func wheel(_ recognizer: UIPanGestureRecognizer) {
            guard let scroll = recognizer.view as? UIScrollView else { return }
            let delta = recognizer.translation(in: scroll).y; recognizer.setTranslation(.zero, in: scroll)
            scroll.setZoomScale(min(5, max(1, scroll.zoomScale - delta * 0.01)), animated: false)
            if recognizer.state == .ended { zoom.wrappedValue = scroll.zoomScale }
        }
    }
}

// UIKit lays out after make/updateUIView; initialize the image when real bounds arrive.
private final class MediaScrollView: UIScrollView {
    weak var media: UIImageView?
    private var lastSize = CGSize.zero
    override func layoutSubviews() {
        super.layoutSubviews()
        guard !bounds.isEmpty, bounds.size != lastSize else { return }
        let scale = zoomScale
        setZoomScale(1, animated: false)
        media?.frame = CGRect(origin: .zero, size: bounds.size)
        contentSize = bounds.size
        lastSize = bounds.size
        setZoomScale(scale, animated: false)
    }
}
