import SwiftUI

final class BlockRegistry {
    private var definitions: [String: BlockDefinition] = [:]
    private let unsupportedRenderer = UnsupportedBlockRenderer()

    static func defaultRegistry() -> BlockRegistry {
        let registry = BlockRegistry()
        registry.register(ParagraphBlockRenderer())
        return registry
    }

    func register<Renderer: MokelayBlockRenderer>(_ renderer: Renderer) {
        definitions[renderer.type] = BlockDefinition(renderer)
    }

    func definition(for type: String) -> BlockDefinition? {
        definitions[type]
    }

    func render(block: MokelayBlock, context: RenderContext) -> AnyView {
        if let definition = definition(for: block.type) {
            return definition.render(block: block, context: context)
        }

        return unsupportedRenderer.render(block: block, context: context)
    }
}
