import SwiftUI
import VisionKit
import Vision
import PhotosUI
import AVFoundation

struct HostDashboard: View {
    @Environment(AppStore.self) private var store
    @State private var selected: CampusEvent?
    @State private var create = false
    var body: some View {
        List {
            let items = store.scopedEvents.filter { $0.hostID == store.profile.id }.sorted { $0.start > $1.start }
            if items.isEmpty { EmptyState(symbol: "calendar.badge.plus", title: "发起你的第一场活动", subtitle: "从一次分享会、一场比赛或一次小聚开始。") }
            ForEach(items) { event in Button { selected = event } label: { EventRow(event: event) }.buttonStyle(.plain) }
        }.navigationTitle("主办方工作台").toolbar { Button { create = true } label: { Image(systemName: "plus") }.accessibilityLabel("创建活动") }.sheet(isPresented: $create) { EventEditorView() }.sheet(item: $selected) { ManageEventView(eventID: $0.id) }
    }
}

struct ManageEventView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var eventID: UUID
    @State private var editing = false
    @State private var scanning = false
    @State private var cancel = false
    @State private var code = ""
    @State private var announcement = ""
    @State private var message: String?
    @State private var search = ""
    var registrations: [Registration] { store.state.registrations.filter { $0.eventID == eventID && $0.status.active } }
    var body: some View {
        NavigationStack {
            if let event = store.event(eventID), event.hostID == store.profile.id {
                List {
                    Section {
                        HStack(spacing: 14) { EventCover(event: event).frame(width: 78, height: 78).clipped().clipShape(RoundedRectangle(cornerRadius: 15)); VStack(alignment: .leading, spacing: 8) { Text(event.title).font(.headline); Text(event.cancelled ? "活动已取消" : "已发布").font(.caption).foregroundStyle(.secondary) } }
                        HStack { metric("报名", store.count(event)); Spacer(); metric("待审核", registrations.filter { $0.status == .pending }.count); Spacer(); metric("已签到", registrations.filter { $0.status == .checkedIn }.count) }.padding(.vertical, 12)
                    }
                    if !event.cancelled {
                        Section {
                            Button { editing = true } label: { Label("编辑活动", systemImage: "square.and.pencil") }
                            ShareLink(item: event.shareText) { Label("邀请同学", systemImage: "square.and.arrow.up") }
                            Button { scanning = true } label: { Label("扫码核销", systemImage: "qrcode.viewfinder") }
                        }
                        Section("手动核销") {
                            TextField("粘贴入场凭证中的核销码", text: $code).textInputAutocapitalization(.never).autocorrectionDisabled()
                            Button("核销并签到") { submit(code, event: event) }.disabled(code.isEmpty)
                        }
                    }
                    Section("报名名单") {
                        if registrations.isEmpty { Text("还没有同学报名").foregroundStyle(.secondary) }
                        ForEach(registrations) { reg in
                            HStack(spacing: 12) { HostAvatar(name: reg.studentID == store.profile.id ? store.profile.name : "同学"); VStack(alignment: .leading, spacing: 6) { Text(reg.studentID == store.profile.id ? store.profile.name : "参与同学").font(.subheadline.bold()); Tag(text: reg.status.rawValue) }; Spacer(); if [.pending, .waitlisted].contains(reg.status) && !event.cancelled { Button("通过") { store.approve(reg, event: event); consumeError() }.buttonStyle(.bordered) } }
                        }
                    }
                    if !event.cancelled {
                        Section("活动通知") {
                            TextField("通知内容", text: $announcement, axis: .vertical).lineLimit(3...6)
                            Button("发布通知") {
                                let body = announcement.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !body.isEmpty else { return }
                                if store.update({ $0.notices.insert(ActivityNotice(title: "主办方通知", body: body, eventID: eventID), at: 0) }) { announcement = ""; message = "通知已保存，可在消息页查看。" } else { consumeError() }
                            }.disabled(announcement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        Section { Button("取消活动", role: .destructive) { cancel = true } }
                    }
                }.navigationTitle("管理活动").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } } }
                    .sheet(isPresented: $editing) { EventEditorView(existing: event) }
                    .sheet(isPresented: $scanning) { ScanTicketView { value in scanning = false; submit(value, event: event) } }
                    .confirmationDialog("确定取消「\(event.title)」？报名将一并取消。", isPresented: $cancel, titleVisibility: .visible) { Button("取消活动", role: .destructive) { store.cancelEvent(event); consumeError() } }
                    .alert("活动管理", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("知道了") { message = nil } } message: { Text(message ?? "") }
            } else { ContentUnavailableView("无管理权限", systemImage: "lock") }
        }
    }
    func metric(_ title: String, _ value: Int) -> some View { VStack(alignment: .leading, spacing: 7) { Text(String(value)).font(.title.bold()); Text(title).font(.caption).foregroundStyle(.secondary) } }
    func consumeError() { if let error = store.error { message = error; store.error = nil } }
    func submit(_ value: String, event: CampusEvent) { if store.checkIn(value, event: event) { code = ""; message = "签到成功。重复核销不会重复计分。" } else { consumeError() } }
}

struct ScanTicketView: View {
    @Environment(\.dismiss) private var dismiss
    var onCode: (String) -> Void
    @State private var photo: PhotosPickerItem?
    @State private var message: String?
    @State private var camera = false
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if camera && DataScannerViewController.isSupported && DataScannerViewController.isAvailable { QRScanner(onCode: onCode).clipShape(RoundedRectangle(cornerRadius: 22)).frame(minHeight: 350) }
                else { EmptyState(symbol: "qrcode.viewfinder", title: "扫描入场凭证", subtitle: DataScannerViewController.isSupported ? "将同学的入场二维码放入取景框。" : "当前模拟器无法使用摄像头，可选择二维码图片或返回手动输入核销码。") }
                if DataScannerViewController.isSupported { Button { Task { let allowed = await AVCaptureDevice.requestAccess(for: .video); if allowed { camera = true } else { message = "请在系统设置中允许活动君使用相机，或从相册选择二维码。" } } } label: { Label("打开相机", systemImage: "camera").frame(maxWidth: .infinity) }.buttonStyle(PrimaryButton()) }
                PhotosPicker(selection: $photo, matching: .images) { Label("从相册识别二维码", systemImage: "photo").frame(maxWidth: .infinity) }.buttonStyle(.bordered).controlSize(.large)
                Spacer()
            }.padding(24).navigationTitle("扫码核销").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .topBarTrailing) { Button("取消") { dismiss() } } }
                .onChange(of: photo) { _, item in Task {
                    if let data = try? await item?.loadTransferable(type: Data.self), let image = UIImage(data: data)?.cgImage {
                        let request = VNDetectBarcodesRequest(); request.symbologies = [.qr]
                        try? VNImageRequestHandler(cgImage: image).perform([request])
                        if let result = request.results?.compactMap(\.payloadStringValue).first { onCode(result) } else { message = "没有识别到二维码，请选择清晰、完整的凭证图片。" }
                    } else { message = "图片读取失败，请重新选择。" }
                } }
                .alert("扫码核销", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("知道了") { message = nil } } message: { Text(message ?? "") }
        }
    }
}
struct QRScanner: UIViewControllerRepresentable {
    var onCode: (String) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(onCode: onCode) }
    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(recognizedDataTypes: [.barcode(symbologies: [.qr])], qualityLevel: .balanced, recognizesMultipleItems: false, isGuidanceEnabled: true, isHighlightingEnabled: true)
        scanner.delegate = context.coordinator
        try? scanner.startScanning()
        return scanner
    }
    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {}
    static func dismantleUIViewController(_ controller: DataScannerViewController, coordinator: Coordinator) { controller.stopScanning() }
    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onCode: (String) -> Void
        var processed = false
        init(onCode: @escaping (String) -> Void) { self.onCode = onCode }
        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !processed else { return }
            for item in addedItems { if case .barcode(let barcode) = item, let value = barcode.payloadStringValue { processed = true; dataScanner.stopScanning(); onCode(value); return } }
        }
    }
}

struct LocalAdminView: View {
    @Environment(AppStore.self) private var store
    @State private var selectedID: UUID?
    @State private var points = "0.50"
    @State private var mode = CreditMode.review
    @State private var message: String?
    var body: some View {
        Form {
            Section { Text("此页用于预览教师计分流程，只修改本机示例记录。正式教师权限与学校综测后台尚未接入。").font(.footnote).foregroundStyle(.secondary) }
            Section("活动计分规则") {
                Picker("活动", selection: $selectedID) { Text("选择活动").tag(UUID?.none); ForEach(store.events.filter { $0.space == .campus }) { Text($0.title).tag(Optional($0.id)) } }
                TextField("综测分", text: $points).keyboardType(.decimalPad)
                Picker("计入方式", selection: $mode) { ForEach(CreditMode.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                Button("保存规则") {
                    guard let selectedID, points.range(of: #"^\d{1,3}(\.\d{1,2})?$"#, options: .regularExpression) != nil, let decimal = Decimal(string: points, locale: Locale(identifier: "en_US_POSIX")), decimal >= 0, decimal <= 100 else { message = "请选择活动并输入 0～100 的分数，最多保留两位小数。"; return }
                    let hundredths = NSDecimalNumber(decimal: decimal * 100)
                    guard hundredths == NSDecimalNumber(value: hundredths.intValue) else { message = "分数最多保留两位小数。"; return }
                    if store.update({ state in guard let i = state.events.firstIndex(where: { $0.id == selectedID }) else { return }; state.events[i].creditHundredths = hundredths.intValue; state.events[i].creditMode = mode }) { message = "规则已保存，适用于后续签到。已有签到记录保持原分值。" }
                }.disabled(selectedID == nil)
            }
            Section("待审核记录") {
                let pending = store.state.registrations.filter { $0.status == .checkedIn && $0.creditHundredths > 0 && !$0.creditApproved && store.event($0.eventID)?.space == .campus }
                if pending.isEmpty { Text("暂无待审核记录").foregroundStyle(.secondary) }
                ForEach(pending) { reg in
                    HStack { VStack(alignment: .leading, spacing: 5) { Text(store.event(reg.eventID)?.title ?? "活动").font(.subheadline); Text(String(format: "%.2f 分", Double(reg.creditHundredths) / 100)).font(.caption).foregroundStyle(.secondary) }; Spacer(); Button("通过") { store.update { state in if let i = state.registrations.firstIndex(where: { $0.id == reg.id }) { state.registrations[i].creditApproved = true } } } }
                }
            }
        }.navigationTitle("本机管理预览").navigationBarTitleDisplayMode(.inline)
            .onChange(of: selectedID) { _, id in if let id, let e = store.event(id) { points = String(format: "%.2f", Double(e.creditHundredths) / 100); mode = e.creditMode } }
            .alert("计分规则", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("知道了") { message = nil } } message: { Text(message ?? "") }
    }
}
