import Foundation

struct RenderContext {
    let pageUUID: String
    let apiClient: MokelayPageAPI
    let navigateToPage: (String) -> Void
}
