import SwiftUI

struct PageRenderer: View {
    let page: MokelayPage
    let registry: BlockRegistry
    @ObservedObject var runtime: MokelayRuntime

    var body: some View {
        let context = RenderContext(
            pageUUID: page.uuid,
            registry: registry,
            runtime: runtime
        )

        VStack(alignment: .leading, spacing: 16) {
            ForEach(page.blocks) { block in
                registry.render(block: block, context: context)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            registerPageHandle()
        }
        .onDisappear {
            runtime.unregister(id: page.uuid)
        }
    }

    private func registerPageHandle() {
        runtime.register(
            MokelayBlockRuntimeHandle(
                id: page.uuid,
                type: "MPage",
                getData: {
                    [
                        "blocks": .array(page.blocks.map(\.jsonValue))
                    ]
                },
                callMethod: { methodName, _ in
                    if methodName == "close" {
                        runtime.dismissDialog()
                        return .null
                    }

                    if methodName == "getData" {
                        return .object([
                            "blocks": .array(page.blocks.map(\.jsonValue))
                        ])
                    }

                    return nil
                }
            )
        )
    }
}
