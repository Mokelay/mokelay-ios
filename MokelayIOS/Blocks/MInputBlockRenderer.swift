import SwiftUI

struct MInputBlockRenderer: MokelayBlockRenderer {
    let type = "MInput"

    func render(block: MokelayBlock, context: RenderContext) -> AnyView {
        AnyView(MInputBlockView(block: block, context: context))
    }
}

@MainActor
private final class MInputModel: ObservableObject {
    let block: MokelayBlock
    let runtime: MokelayRuntime
    let placeholder: String

    @Published var value: String
    @Published var focusToken = UUID()

    init(block: MokelayBlock, runtime: MokelayRuntime) {
        self.block = block
        self.runtime = runtime
        self.placeholder = block.stringData("placeholder") ?? ""
        self.value = block.stringData("value") ?? ""
    }

    func register() {
        runtime.register(
            MokelayBlockRuntimeHandle(
                id: block.id,
                type: block.type,
                getData: { [weak self] in
                    guard let self else {
                        return [:]
                    }

                    return ["value": .string(self.value)]
                },
                callMethod: { [weak self] methodName, _ in
                    guard let self else {
                        return nil
                    }

                    if methodName == "focus" {
                        self.focusToken = UUID()
                        return .null
                    }

                    if methodName == "getData" {
                        return .object(["value": .string(self.value)])
                    }

                    return nil
                }
            )
        )
    }
}

private struct MInputBlockView: View {
    @StateObject private var model: MInputModel
    @FocusState private var isFocused: Bool

    init(block: MokelayBlock, context: RenderContext) {
        _model = StateObject(wrappedValue: MInputModel(block: block, runtime: context.runtime))
    }

    var body: some View {
        TextField(model.placeholder, text: $model.value)
            .textFieldStyle(.plain)
            .focused($isFocused)
            .font(.system(size: 14))
            .padding(.horizontal, 10)
            .frame(minHeight: 38)
            .background(Color(uiColor: .systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color(uiColor: .separator), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .onAppear {
                model.register()
            }
            .onDisappear {
                model.runtime.unregister(id: model.block.id)
            }
            .onChange(of: model.focusToken) { _ in
                isFocused = true
            }
    }
}
