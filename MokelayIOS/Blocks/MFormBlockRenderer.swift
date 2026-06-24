import SwiftUI

struct MFormBlockRenderer: MokelayBlockRenderer {
    let type = "MForm"

    func render(block: MokelayBlock, context: RenderContext) -> AnyView {
        AnyView(MFormBlockView(block: block, context: context))
    }
}

private struct MFormItem: Identifiable, Equatable {
    let id: String
    let labelName: String
    let variableName: String
    let fieldDataType: String
    let layout: String
    let editor: MokelayBlock?

    static func items(from value: JSONValue?) -> [MFormItem] {
        value?.arrayValue?.enumerated().compactMap { index, item in
            guard let object = item.objectValue else {
                return nil
            }

            let variableName = object["variableName"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "field_\(index)"

            return MFormItem(
                id: "\(variableName)-\(index)",
                labelName: object["labelName"]?.stringValue ?? variableName,
                variableName: variableName,
                fieldDataType: object["fieldDataType"]?.stringValue ?? "string",
                layout: object["layout"]?.stringValue == "Horizontal" ? "Horizontal" : "Vertical",
                editor: object["editor"].flatMap(MokelayBlock.fromJSONValue)
            )
        } ?? []
    }
}

private struct MFormBlockView: View {
    let block: MokelayBlock
    let context: RenderContext

    private var items: [MFormItem] {
        MFormItem.items(from: block.data["items"])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(items) { item in
                MFormItemView(item: item, context: context)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            registerForm()
        }
        .onDisappear {
            context.runtime.unregister(id: block.id)
        }
    }

    private func registerForm() {
        let formItems = items
        let blockID = block.id
        let runtime = context.runtime

        runtime.register(
            MokelayBlockRuntimeHandle(
                id: blockID,
                type: block.type,
                getData: {
                    await formData(items: formItems, runtime: runtime, excluding: blockID)
                },
                callMethod: { methodName, _ in
                    if methodName == "getData" {
                        return .object(await formData(items: formItems, runtime: runtime, excluding: blockID))
                    }

                    return nil
                }
            )
        )
    }

    private func formData(items: [MFormItem], runtime: MokelayRuntime, excluding blockID: String) async -> [String: JSONValue] {
        let blockData = await runtime.getBlockDataContext(excluding: blockID)

        return Dictionary(uniqueKeysWithValues: items.map { item in
            let editorID = item.editor?.id ?? ""
            let runtimeValue = blockData[editorID]?["value"]
            let fallbackValue = item.editor?.data["value"] ?? .string("")
            return (item.variableName, runtimeValue ?? fallbackValue)
        })
    }
}

private struct MFormItemView: View {
    let item: MFormItem
    let context: RenderContext

    var body: some View {
        Group {
            if item.layout == "Horizontal" {
                HStack(alignment: .top, spacing: 12) {
                    label
                        .frame(minWidth: 96, alignment: .leading)
                    editor
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    label
                    editor
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var label: some View {
        Text(item.labelName)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.secondary)
            .padding(.top, item.layout == "Horizontal" ? 9 : 0)
    }

    @ViewBuilder
    private var editor: some View {
        if let editorBlock = item.editor {
            context.registry.render(block: editorBlock, context: context)
        } else {
            Text("未配置字段")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(minHeight: 38)
        }
    }
}
