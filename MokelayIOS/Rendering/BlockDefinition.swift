import SwiftUI

protocol MokelayBlockRenderer {
    var type: String { get }

    func render(block: MokelayBlock, context: RenderContext) -> AnyView
}

struct BlockDefinition {
    let type: String

    private let renderBody: (MokelayBlock, RenderContext) -> AnyView

    init<Renderer: MokelayBlockRenderer>(_ renderer: Renderer) {
        type = renderer.type
        renderBody = renderer.render
    }

    func render(block: MokelayBlock, context: RenderContext) -> AnyView {
        renderBody(block, context)
    }
}
