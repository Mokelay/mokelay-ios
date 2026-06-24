import Foundation

struct RenderContext {
    let pageUUID: String
    let registry: BlockRegistry
    let runtime: MokelayRuntime
    let isCompact: Bool

    init(
        pageUUID: String,
        registry: BlockRegistry,
        runtime: MokelayRuntime,
        isCompact: Bool = false
    ) {
        self.pageUUID = pageUUID
        self.registry = registry
        self.runtime = runtime
        self.isCompact = isCompact
    }

    func compact() -> RenderContext {
        RenderContext(
            pageUUID: pageUUID,
            registry: registry,
            runtime: runtime,
            isCompact: true
        )
    }
}
