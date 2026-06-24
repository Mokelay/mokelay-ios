import SwiftUI
#if os(iOS)
import AVFoundation
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct HomeScreen: View {
    @State private var pageUUID = ""
    @State private var isSystemPage = false
    @State private var destination: PageDestination?
    @State private var isShowingPage = false
    @State private var isShowingScanner = false
    @State private var scanErrorMessage = ""
    @FocusState private var isUUIDFieldFocused: Bool

    private var trimmedUUID: String {
        pageUUID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canNavigate: Bool {
        !trimmedUUID.isEmpty
    }

    var body: some View {
        let view = ZStack {
            systemBackgroundColor
                .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer(minLength: 64)

                logo

                VStack(spacing: 16) {
                    uuidInput
                    systemPageCheckbox
                    jumpButton
                    #if os(iOS)
                    scanButton
                    #endif
                    scanErrorText
                }
                .frame(maxWidth: 520)

                NavigationLink(isActive: $isShowingPage) {
                    if let destination {
                        PageScreen(uuid: destination.uuid, source: destination.source)
                    } else {
                        EmptyView()
                    }
                } label: {
                    EmptyView()
                }
                .hidden()

                Spacer(minLength: 120)
            }
            .padding(.horizontal, 28)
        }

        #if os(iOS)
        return view
            .sheet(isPresented: $isShowingScanner) {
                QRCodeScannerSheet(onCodeScanned: handleScannedCode)
            }
            .navigationBarHidden(true)
        #else
        return view
        #endif
    }

    private var logo: some View {
        VStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color(red: 0.06, green: 0.19, blue: 0.16))
                    .shadow(color: Color.black.opacity(0.14), radius: 18, x: 0, y: 10)

                Text("M")
                    .font(.system(size: 70, weight: .black, design: .rounded))
                    .foregroundColor(Color(red: 0.84, green: 0.96, blue: 0.42))
                    .offset(y: -1)
            }
            .frame(width: 108, height: 108)

            Text("Mokelay")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Mokelay")
    }

    private var uuidInput: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.secondary)

            TextField("请输入页面UUID", text: $pageUUID)
                .focused($isUUIDFieldFocused)
                .submitLabel(.go)
                .mokelayUUIDInputBehavior()
                .onSubmit(navigateToPage)
                .font(.body)
        }
        .padding(.horizontal, 18)
        .frame(height: 54)
        .background(inputBackgroundColor)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 16, x: 0, y: 8)
    }

    private var systemPageCheckbox: some View {
        Button {
            isSystemPage.toggle()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isSystemPage ? "checkmark.square.fill" : "square")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(isSystemPage ? .accentColor : .secondary)

                Text("是否内置页面")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("是否内置页面")
        .accessibilityValue(isSystemPage ? "已选择" : "未选择")
    }

    private var jumpButton: some View {
        Button(action: navigateToPage) {
            Text("跳转")
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 50)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(!canNavigate)
    }

    #if os(iOS)
    private var scanButton: some View {
        Button {
            scanErrorMessage = ""
            isShowingScanner = true
        } label: {
            Label("扫描二维码", systemImage: "qrcode.viewfinder")
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 50)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }
    #endif

    @ViewBuilder
    private var scanErrorText: some View {
        if !scanErrorMessage.isEmpty {
            Text(scanErrorMessage)
                .font(.footnote)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
        }
    }

    private func navigateToPage() {
        guard canNavigate else {
            return
        }

        navigateToPage(manualPageDestination(uuid: trimmedUUID, isSystemPage: isSystemPage))
    }

    private func navigateToPage(_ destination: PageDestination) {
        self.destination = destination
        isUUIDFieldFocused = false
        isShowingPage = true
    }

    private func handleScannedCode(_ scannedText: String) {
        guard let destination = extractPageDestination(from: scannedText) else {
            scanErrorMessage = "未识别到 Mokelay 预览地址"
            isShowingScanner = false
            return
        }

        scanErrorMessage = ""
        pageUUID = destination.uuid
        isSystemPage = destination.source == .system
        isShowingScanner = false
        navigateToPage(destination)
    }

    private var systemBackgroundColor: Color {
        #if os(iOS)
        return Color(UIColor.systemBackground)
        #elseif os(macOS)
        return Color(NSColor.windowBackgroundColor)
        #else
        return Color.clear
        #endif
    }

    private var inputBackgroundColor: Color {
        #if os(iOS)
        return Color(UIColor.secondarySystemBackground)
        #elseif os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color.gray.opacity(0.12)
        #endif
    }
}

struct PageDestination: Equatable {
    let uuid: String
    let source: PageSource
}

func extractPageUUID(from scannedText: String) -> String? {
    extractPageDestination(from: scannedText)?.uuid
}

func manualPageDestination(uuid: String, isSystemPage: Bool) -> PageDestination {
    PageDestination(
        uuid: uuid.trimmingCharacters(in: .whitespacesAndNewlines),
        source: isSystemPage ? .system : .user
    )
}

func extractPageDestination(from scannedText: String) -> PageDestination? {
    let trimmedText = scannedText.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !trimmedText.isEmpty else {
        return nil
    }

    if UUID(uuidString: trimmedText) != nil {
        return PageDestination(uuid: trimmedText, source: .user)
    }

    if let url = URL(string: trimmedText) {
        if let fragment = url.fragment,
           let destination = extractPageDestinationFromPreviewPath(fragment) {
            return destination
        }

        if let destination = extractPageDestinationFromPreviewPath(url.path, fallbackQuery: url.query) {
            return destination
        }
    }

    if let hashRange = trimmedText.range(of: "#") {
        let fragment = String(trimmedText[hashRange.upperBound...])
        if let destination = extractPageDestinationFromPreviewPath(fragment) {
            return destination
        }
    }

    return nil
}

private func extractPageUUIDFromPreviewPath(_ path: String) -> String? {
    extractPageDestinationFromPreviewPath(path)?.uuid
}

private func extractPageDestinationFromPreviewPath(_ path: String, fallbackQuery: String? = nil) -> PageDestination? {
    let normalizedPath = path.hasPrefix("/") ? path : "/\(path)"
    let pathParts = normalizedPath.split(separator: "?", maxSplits: 1).map(String.init)
    let pathWithoutQuery = pathParts.first ?? normalizedPath
    let query = pathParts.count > 1 ? pathParts[1] : fallbackQuery
    let parts = pathWithoutQuery.split(separator: "/", omittingEmptySubsequences: true)

    guard (parts.count == 2 || parts.count == 3),
          String(parts[0]) == "pages",
          parts.count == 2 || String(parts[2]) == "preview" else {
        return nil
    }

    let encodedUUID = String(parts[1])
    let source = querySource(query) ?? .user
    return PageDestination(uuid: encodedUUID.removingPercentEncoding ?? encodedUUID, source: source)
}

private func querySource(_ query: String?) -> PageSource? {
    guard let query else {
        return nil
    }

    var components = URLComponents()
    components.query = query
    let sourceValue = components.queryItems?.first(where: { $0.name == "source" })?.value
    return sourceValue == "system" ? .system : .user
}

#if os(iOS)
private struct QRCodeScannerSheet: View {
    let onCodeScanned: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var cameraAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)

    var body: some View {
        NavigationView {
            ZStack {
                switch cameraAuthorizationStatus {
                case .authorized:
                    scannerView
                case .notDetermined:
                    permissionPendingView
                case .denied, .restricted:
                    cameraUnavailableView(
                        title: "无法使用摄像头",
                        message: "请在系统设置中允许 Mokelay 使用摄像头后再扫描二维码。"
                    )
                @unknown default:
                    cameraUnavailableView(
                        title: "无法使用摄像头",
                        message: "当前设备暂不支持二维码扫描。"
                    )
                }
            }
            .navigationTitle("扫描二维码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
            .onAppear(perform: requestCameraAccessIfNeeded)
        }
    }

    private var scannerView: some View {
        ZStack {
            QRCodeScannerView(onCodeScanned: onCodeScanned)
                .ignoresSafeArea()

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.95), lineWidth: 3)
                .frame(width: 240, height: 240)

            VStack {
                Spacer()
                Text("将二维码放入取景框内")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.55))
                    .clipShape(Capsule())
                    .padding(.bottom, 42)
            }
        }
    }

    private var permissionPendingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("正在请求摄像头权限...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func cameraUnavailableView(title: String, message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "camera.fill")
                .font(.system(size: 36, weight: .semibold))
                .foregroundColor(.secondary)

            Text(title)
                .font(.title3.bold())

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func requestCameraAccessIfNeeded() {
        guard cameraAuthorizationStatus == .notDetermined else {
            return
        }

        AVCaptureDevice.requestAccess(for: .video) { isGranted in
            DispatchQueue.main.async {
                cameraAuthorizationStatus = isGranted ? .authorized : .denied
            }
        }
    }
}

private struct QRCodeScannerView: UIViewControllerRepresentable {
    let onCodeScanned: (String) -> Void

    func makeUIViewController(context: Context) -> QRCodeScannerViewController {
        let viewController = QRCodeScannerViewController()
        viewController.onCodeScanned = context.coordinator.handleScannedCode
        return viewController
    }

    func updateUIViewController(_ uiViewController: QRCodeScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCodeScanned: onCodeScanned)
    }

    final class Coordinator {
        private let onCodeScanned: (String) -> Void
        private var hasScannedCode = false

        init(onCodeScanned: @escaping (String) -> Void) {
            self.onCodeScanned = onCodeScanned
        }

        func handleScannedCode(_ code: String) {
            guard !hasScannedCode else {
                return
            }

            hasScannedCode = true
            onCodeScanned(code)
        }
    }
}

private final class QRCodeScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCodeScanned: ((String) -> Void)?

    private let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var didConfigureSession = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureCaptureSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startCaptureSession()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopCaptureSession()
    }

    private func configureCaptureSession() {
        guard !didConfigureSession else {
            return
        }

        guard let videoDevice = AVCaptureDevice.default(for: .video),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
              captureSession.canAddInput(videoInput) else {
            showConfigurationError()
            return
        }

        captureSession.addInput(videoInput)

        let metadataOutput = AVCaptureMetadataOutput()
        guard captureSession.canAddOutput(metadataOutput) else {
            showConfigurationError()
            return
        }

        captureSession.addOutput(metadataOutput)
        metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
        metadataOutput.metadataObjectTypes = [.qr]

        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        self.previewLayer = previewLayer
        didConfigureSession = true
    }

    private func startCaptureSession() {
        guard didConfigureSession, !captureSession.isRunning else {
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [captureSession] in
            captureSession.startRunning()
        }
    }

    private func stopCaptureSession() {
        guard captureSession.isRunning else {
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [captureSession] in
            captureSession.stopRunning()
        }
    }

    private func showConfigurationError() {
        let label = UILabel()
        label.text = "无法启动摄像头"
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              metadataObject.type == .qr,
              let scannedValue = metadataObject.stringValue else {
            return
        }

        stopCaptureSession()
        onCodeScanned?(scannedValue)
    }
}
#endif

private extension View {
    @ViewBuilder
    func mokelayUUIDInputBehavior() -> some View {
        #if os(iOS)
        self
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        #else
        self
        #endif
    }
}
