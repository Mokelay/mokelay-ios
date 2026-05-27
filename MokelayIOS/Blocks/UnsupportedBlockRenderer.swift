import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct UnsupportedBlockRenderer: MokelayBlockRenderer {
    let type = "__unsupported__"

    func render(block: MokelayBlock, context: RenderContext) -> AnyView {
        AnyView(
            VStack(alignment: .leading, spacing: 6) {
                Text("暂不支持渲染：\(block.type)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)

                Text("block id: \(block.id)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(secondaryBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        )
    }

    private var secondaryBackgroundColor: Color {
        #if os(iOS)
        return Color(UIColor.secondarySystemBackground)
        #elseif os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color.gray.opacity(0.12)
        #endif
    }
}
