import SwiftUI

struct PageRenderer: View {
    let page: MokelayPage
    let registry: BlockRegistry
    let apiClient: MokelayPageAPI
    let onNavigateToPage: (String) -> Void

    var body: some View {
        let context = RenderContext(
            pageUUID: page.uuid,
            apiClient: apiClient,
            navigateToPage: onNavigateToPage
        )

        VStack(alignment: .leading, spacing: 16) {
            ForEach(page.blocks) { block in
                registry.render(block: block, context: context)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
