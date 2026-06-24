import SwiftUI

struct MButtonBlockRenderer: MokelayBlockRenderer {
    let type = "MButton"

    func render(block: MokelayBlock, context: RenderContext) -> AnyView {
        AnyView(MButtonBlockView(block: block, context: context))
    }
}

private struct MButtonBlockView: View {
    let block: MokelayBlock
    let context: RenderContext

    private var label: String {
        block.stringData("label")?.isEmpty == false ? block.stringData("label")! : "提交"
    }

    private var variant: String {
        let value = block.stringData("variant") ?? "primary"
        return value == "secondary" || value == "ghost" ? value : "primary"
    }

    private var align: String {
        block.stringData("align") ?? "left"
    }

    var body: some View {
        HStack {
            if align == "right" {
                Spacer(minLength: 0)
            }

            button

            if align != "right", align != "left" {
                Spacer(minLength: 0)
            }

            if align == "left" {
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: context.isCompact ? nil : .infinity, alignment: alignment)
    }

    private var button: some View {
        Button {
            context.runtime.trigger(eventName: "click", on: block)
        } label: {
            Text(label)
                .font(.system(size: context.isCompact ? 12 : 14, weight: .semibold))
                .lineLimit(1)
                .padding(.horizontal, context.isCompact ? 10 : 16)
                .frame(minHeight: context.isCompact ? 30 : 40)
        }
        .buttonStyle(.plain)
        .foregroundColor(foregroundColor)
        .background(backgroundColor)
        .overlay(
            RoundedRectangle(cornerRadius: context.isCompact ? 6 : 8, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: context.isCompact ? 6 : 8, style: .continuous))
    }

    private var alignment: Alignment {
        if align == "center" {
            return .center
        }

        if align == "right" {
            return .trailing
        }

        return .leading
    }

    private var foregroundColor: Color {
        switch variant {
        case "primary":
            return .white
        case "secondary":
            return .primary
        default:
            return Color(red: 0.20, green: 0.25, blue: 0.33)
        }
    }

    private var backgroundColor: Color {
        switch variant {
        case "primary":
            return Color(red: 0.31, green: 0.27, blue: 0.90)
        case "secondary":
            return Color(uiColor: .systemBackground)
        default:
            return .clear
        }
    }

    private var borderColor: Color {
        switch variant {
        case "primary":
            return Color(red: 0.31, green: 0.27, blue: 0.90)
        case "secondary":
            return Color(uiColor: .separator)
        default:
            return .clear
        }
    }
}
