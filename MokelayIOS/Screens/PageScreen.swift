import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct PageScreen: View {
    let uuid: String
    let source: PageSource

    private let apiClient: MokelayPageAPI
    private let registry: BlockRegistry

    @StateObject private var viewModel: PageViewModel
    @StateObject private var runtime: MokelayRuntime
    @State private var destination: PageDestination?
    @State private var isShowingDestination = false

    init(
        uuid: String,
        source: PageSource = .user,
        apiClient: MokelayPageAPI = .shared,
        registry: BlockRegistry = .defaultRegistry()
    ) {
        self.uuid = uuid
        self.source = source
        self.apiClient = apiClient
        self.registry = registry
        _viewModel = StateObject(wrappedValue: PageViewModel(apiClient: apiClient))
        _runtime = StateObject(wrappedValue: MokelayRuntime(apiClient: apiClient))
    }

    var body: some View {
        let view = ZStack {
            content

            NavigationLink(isActive: $isShowingDestination) {
                if let destination {
                    PageScreen(
                        uuid: destination.uuid,
                        source: destination.source,
                        apiClient: apiClient,
                        registry: registry
                    )
                } else {
                    EmptyView()
                }
            } label: {
                EmptyView()
            }
            .hidden()
        }
            .navigationTitle(navigationTitle)
            .task(id: "\(source.rawValue):\(uuid)") {
                runtime.configure(navigateToPage: navigateToPage)
                await viewModel.load(uuid: uuid, source: source)
            }
            .sheet(item: $runtime.dialogPresentation, onDismiss: {
                runtime.dismissDialog()
            }) { presentation in
                MokelayDialogPageView(
                    presentation: presentation,
                    apiClient: apiClient,
                    registry: registry,
                    runtime: runtime
                )
            }
            .alert(item: $runtime.confirmPresentation) { presentation in
                Alert(
                    title: Text(presentation.title),
                    message: Text(presentation.content),
                    primaryButton: .cancel(Text("取消")) {
                        runtime.resolveConfirm(false)
                    },
                    secondaryButton: .default(Text("确定")) {
                        runtime.resolveConfirm(true)
                    }
                )
            }

        #if os(iOS)
        return view.navigationBarTitleDisplayMode(.inline)
        #else
        return view
        #endif
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            loadingView
        case .loaded(let page):
            loadedView(page)
        case .failed(let message):
            errorView(message)
        }
    }

    private var navigationTitle: String {
        switch viewModel.state {
        case .loaded(let page):
            return page.name.isEmpty ? page.uuid : page.name
        default:
            return "Mokelay"
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("正在加载页面...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(systemBackgroundColor)
    }

    private func loadedView(_ page: MokelayPage) -> some View {
        ScrollView {
            PageRenderer(
                page: page,
                registry: registry,
                runtime: runtime
            )
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(systemBackgroundColor)
        .refreshable {
            await viewModel.load(uuid: uuid, source: source)
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Text("页面加载失败")
                .font(.title3.bold())

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button {
                Task {
                    await viewModel.load(uuid: uuid, source: source)
                }
            } label: {
                Text("重试")
                    .font(.body.weight(.semibold))
                    .frame(minWidth: 88)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(systemBackgroundColor)
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

    private func navigateToPage(uuid: String, source: PageSource) {
        destination = PageDestination(uuid: uuid, source: source)
        isShowingDestination = true
    }
}

@MainActor
final class PageViewModel: ObservableObject {
    @Published private(set) var state: PageLoadState = .idle

    private let apiClient: MokelayPageAPI

    init(apiClient: MokelayPageAPI) {
        self.apiClient = apiClient
    }

    func load(uuid: String, source: PageSource) async {
        state = .loading

        do {
            let page = try await apiClient.fetchPage(uuid: uuid, source: source)
            state = .loaded(page)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}

enum PageLoadState {
    case idle
    case loading
    case loaded(MokelayPage)
    case failed(String)
}

private struct MokelayDialogPageView: View {
    let presentation: MokelayDialogPresentation
    let apiClient: MokelayPageAPI
    let registry: BlockRegistry
    @ObservedObject var runtime: MokelayRuntime

    @StateObject private var viewModel: PageViewModel

    init(
        presentation: MokelayDialogPresentation,
        apiClient: MokelayPageAPI,
        registry: BlockRegistry,
        runtime: MokelayRuntime
    ) {
        self.presentation = presentation
        self.apiClient = apiClient
        self.registry = registry
        self.runtime = runtime
        _viewModel = StateObject(wrappedValue: PageViewModel(apiClient: apiClient))
    }

    var body: some View {
        NavigationView {
            content
                .navigationTitle(presentation.title)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("关闭") {
                            runtime.dismissDialog()
                        }
                    }
                }
                .task(id: "\(presentation.pageSource.rawValue):\(presentation.pageUUID)") {
                    await viewModel.load(uuid: presentation.pageUUID, source: presentation.pageSource)
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            VStack(spacing: 12) {
                ProgressView()
                Text("正在加载页面...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded(let page):
            ScrollView {
                PageRenderer(
                    page: page,
                    registry: registry,
                    runtime: runtime
                )
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .failed(let message):
            VStack(spacing: 12) {
                Text("页面加载失败")
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
