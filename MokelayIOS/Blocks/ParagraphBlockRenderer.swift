import SwiftUI

struct ParagraphBlockRenderer: MokelayBlockRenderer {
    let type = "paragraph"

    func render(block: MokelayBlock, context: RenderContext) -> AnyView {
        let text = block.stringData("text")?.mokelayPlainTextFromHTML() ?? ""

        return AnyView(
            Text(text)
                .font(.body)
                .lineSpacing(4)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        )
    }
}

extension String {
    func mokelayPlainTextFromHTML() -> String {
        replacingOccurrences(
            of: "<[^>]+>",
            with: "",
            options: .regularExpression
        )
        .replacingOccurrences(of: "&nbsp;", with: " ")
        .replacingOccurrences(of: "&amp;", with: "&")
        .replacingOccurrences(of: "&lt;", with: "<")
        .replacingOccurrences(of: "&gt;", with: ">")
        .replacingOccurrences(of: "&quot;", with: "\"")
        .replacingOccurrences(of: "&#39;", with: "'")
    }
}
