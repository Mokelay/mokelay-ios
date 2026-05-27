import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct PageScreen: View {
    let uuid: String

    private let apiClient: MokelayPageAPI
    private let registry: BlockRegistry
    private let onNavigateToPage: (String) -> Void

    @StateObject private var viewModel: PageViewModel

    init(
        uuid: String,
        apiClient: MokelayPageAPI = .shared,
        registry: BlockRegistry = .defaultRegistry(),
        onNavigateToPage: @escaping (String) -> Void = { _ in }
    ) {
        self.uuid = uuid
        self.apiClient = apiClient
        self.registry = registry
        self.onNavigateToPage = onNavigateToPage
        _viewModel = StateObject(wrappedValue: PageViewModel(apiClient: apiClient))
    }

    var body: some View {
        let view = content
            .navigationTitle(navigationTitle)
            .task(id: uuid) {
                await viewModel.load(uuid: uuid)
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
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(page.name.isEmpty ? page.uuid : page.name)
                        .font(.largeTitle.bold())
                        .foregroundColor(.primary)

                    Text("uuid: \(page.uuid)")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                PageRenderer(
                    page: page,
                    registry: registry,
                    apiClient: apiClient,
                    onNavigateToPage: onNavigateToPage
                )
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(systemBackgroundColor)
        .refreshable {
            await viewModel.load(uuid: uuid)
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
                    await viewModel.load(uuid: uuid)
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
}

@MainActor
final class PageViewModel: ObservableObject {
    @Published private(set) var state: PageLoadState = .idle

    private let apiClient: MokelayPageAPI

    init(apiClient: MokelayPageAPI) {
        self.apiClient = apiClient
    }

    func load(uuid: String) async {
        state = .loading

        do {
            let page = try await apiClient.fetchPage(uuid: uuid)
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
