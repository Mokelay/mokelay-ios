import Foundation
import SwiftUI
#if os(iOS)
import UIKit
#endif

struct MokelayRuntimeInvocation {
    let sourceBlock: MokelayBlock
    let eventConfig: MokelayBlockEvent?
    let actionConfig: MokelayActionConfig?
    let inputs: [String: JSONValue]
}

struct MokelayBlockRuntimeHandle {
    let id: String
    let type: String
    let getData: () async -> [String: JSONValue]
    let callMethod: (String, MokelayRuntimeInvocation) async throws -> JSONValue?
}

struct MokelayConfirmPresentation: Identifiable {
    let id = UUID()
    let title: String
    let content: String
}

struct MokelayDialogPresentation: Identifiable {
    let id = UUID()
    let title: String
    let pageUUID: String
    let pageSource: PageSource
}

enum MokelayRuntimeError: LocalizedError {
    case unsupportedAction(String)
    case actionLoop(String)
    case missingAction(String)
    case invalidDatasource
    case invalidController(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedAction(let action):
            return "Unsupported action: \(action)"
        case .actionLoop(let uuid):
            return "Action graph contains a loop at \(uuid)."
        case .missingAction(let uuid):
            return "Action graph points to missing action: \(uuid)."
        case .invalidDatasource:
            return "Datasource config is invalid."
        case .invalidController(let uuid):
            return "Controller action is invalid: \(uuid)."
        }
    }
}

@MainActor
final class MokelayRuntime: ObservableObject {
    @Published var confirmPresentation: MokelayConfirmPresentation?
    @Published var dialogPresentation: MokelayDialogPresentation?
    @Published var lastErrorMessage: String?

    let apiClient: MokelayPageAPI

    private var handles: [String: MokelayBlockRuntimeHandle] = [:]
    private var confirmContinuation: CheckedContinuation<Bool, Never>?
    private var dialogContinuation: CheckedContinuation<JSONValue, Never>?
    private var navigateToPage: (String, PageSource) -> Void = { _, _ in }

    init(apiClient: MokelayPageAPI) {
        self.apiClient = apiClient
    }

    func configure(navigateToPage: @escaping (String, PageSource) -> Void) {
        self.navigateToPage = navigateToPage
    }

    func register(_ handle: MokelayBlockRuntimeHandle) {
        guard !handle.id.isEmpty else {
            return
        }

        handles[handle.id] = handle
    }

    func unregister(id: String) {
        handles.removeValue(forKey: id)
    }

    func getBlockDataContext(excluding excludedBlockId: String? = nil) async -> [String: [String: JSONValue]] {
        var result: [String: [String: JSONValue]] = [:]

        for handle in handles.values where handle.id != excludedBlockId {
            result[handle.id] = await handle.getData()
        }

        return result
    }

    func callBlockMethod(
        blockId: String,
        methodName: String,
        invocation: MokelayRuntimeInvocation
    ) async throws -> JSONValue? {
        guard !blockId.isEmpty, !methodName.isEmpty,
              let handle = handles[blockId] else {
            return nil
        }

        return try await handle.callMethod(methodName, invocation)
    }

    func trigger(eventName: String, on block: MokelayBlock) {
        let matchingEvents = block.events.filter { $0.event == eventName }

        guard !matchingEvents.isEmpty else {
            return
        }

        for eventConfig in matchingEvents {
            Task {
                do {
                    try await runActionGraph(eventConfig.actions, sourceBlock: block, eventConfig: eventConfig)
                } catch {
                    lastErrorMessage = error.localizedDescription
                }
            }
        }
    }

    func runActionGraph(
        _ actions: [MokelayActionConfig],
        sourceBlock: MokelayBlock,
        eventConfig: MokelayBlockEvent? = nil
    ) async throws {
        guard let firstAction = actions.first else {
            return
        }

        let actionMap = Dictionary(uniqueKeysWithValues: actions.map { ($0.uuid, $0) })
        var state = MokelayActionState(
            blocks: await getBlockDataContext(),
            sourceBlock: sourceBlock
        )
        var visited = Set<String>()
        var currentActionUuid: String? = firstAction.uuid

        while let uuid = currentActionUuid {
            guard !visited.contains(uuid) else {
                throw MokelayRuntimeError.actionLoop(uuid)
            }
            visited.insert(uuid)

            guard let config = actionMap[uuid] else {
                throw MokelayRuntimeError.missingAction(uuid)
            }

            state.blocks = await getBlockDataContext()
            let resolvedInputs = try resolvedInputs(config.inputs, state: state)
            state.actions[config.uuid] = MokelayActionRecord(inputs: resolvedInputs, outputs: [:])

            if isController(config) {
                let node = try selectControllerNode(config, inputs: resolvedInputs)
                currentActionUuid = normalizedNextAction(node.nextAction)
                continue
            }

            let outputs = try await execute(config, inputs: resolvedInputs, state: state, eventConfig: eventConfig)
            let normalizedOutputs = normalizeOutputs(outputs, declaredOutputs: config.outputs)
            state.actions[config.uuid]?.outputs = normalizedOutputs
            currentActionUuid = normalizedNextAction(config.nextAction)
        }
    }

    func resolveConfirm(_ result: Bool) {
        confirmPresentation = nil
        confirmContinuation?.resume(returning: result)
        confirmContinuation = nil
    }

    func dismissDialog(result: JSONValue = .null) {
        dialogPresentation = nil
        dialogContinuation?.resume(returning: result)
        dialogContinuation = nil
    }

    private func resolvedInputs(_ inputs: [String: JSONValue], state: MokelayActionState) throws -> [String: JSONValue] {
        try inputs.mapValues { try MokelayTemplateResolver.resolve($0, state: state) }
    }

    private func isController(_ config: MokelayActionConfig) -> Bool {
        config.type == "controller" || config.action == "if_controller" || config.action == "switch_controller"
    }

    private func execute(
        _ config: MokelayActionConfig,
        inputs: [String: JSONValue],
        state: MokelayActionState,
        eventConfig: MokelayBlockEvent?
    ) async throws -> [String: JSONValue] {
        switch config.action {
        case "confirm":
            let result = await showConfirm(
                title: inputs["title"]?.stringValue ?? "",
                content: inputs["content"].map(MokelayTemplateResolver.stringify) ?? ""
            )
            return ["result": .bool(result)]
        case "open_dialog":
            let closeResult = await showDialog(
                title: inputs["title"]?.stringValue ?? "",
                pageUUID: inputs["pageUUID"]?.stringValue ?? inputs["pageUuid"]?.stringValue ?? "",
                pageSource: inputs["pageSource"]?.stringValue == "system" ? .system : .user
            )
            return ["close_result": closeResult]
        case "execute_ds":
            guard let datasource = MokelayDatasource(value: inputs["dsConfig"] ?? inputs["value"] ?? .object(inputs)) else {
                throw MokelayRuntimeError.invalidDatasource
            }
            let runtimeData = try await MokelayDatasourceRuntime.execute(
                datasource: datasource,
                apiClient: apiClient,
                blocks: state.blocks
            )
            var outputs: [String: JSONValue] = [
                "rawResponse": runtimeData.rawResponse,
                "responses": .object(runtimeData.schemaSelectionData)
            ]
            runtimeData.matchingExternalFieldData.forEach { variable, value in
                outputs[variable] = value
            }
            return outputs
        case "call_block_method":
            let returnData = try await callBlockMethod(
                blockId: inputs["blockId"]?.stringValue ?? "",
                methodName: inputs["method"]?.stringValue ?? "",
                invocation: MokelayRuntimeInvocation(
                    sourceBlock: state.sourceBlock,
                    eventConfig: eventConfig,
                    actionConfig: config,
                    inputs: inputs
                )
            ) ?? .null
            return ["returnData": returnData]
        case "jump_url":
            handleJumpURL(inputs["url"]?.stringValue ?? "")
            return [:]
        default:
            throw MokelayRuntimeError.unsupportedAction(config.action)
        }
    }

    private func showConfirm(title: String, content: String) async -> Bool {
        await withCheckedContinuation { continuation in
            confirmContinuation = continuation
            confirmPresentation = MokelayConfirmPresentation(title: title, content: content)
        }
    }

    private func showDialog(title: String, pageUUID: String, pageSource: PageSource) async -> JSONValue {
        await withCheckedContinuation { continuation in
            dialogContinuation = continuation
            dialogPresentation = MokelayDialogPresentation(
                title: title,
                pageUUID: pageUUID,
                pageSource: pageSource
            )
        }
    }

    private func handleJumpURL(_ value: String) {
        guard !value.isEmpty else {
            return
        }

        if let destination = extractPageDestination(from: value) {
            navigateToPage(destination.uuid, destination.source)
            return
        }

        guard let url = URL(string: value) else {
            return
        }

        #if os(iOS)
        UIApplication.shared.open(url)
        #endif
    }

    private func selectControllerNode(_ config: MokelayActionConfig, inputs: [String: JSONValue]) throws -> MokelayActionNode {
        if config.action == "if_controller" {
            guard let trueNode = config.nodes.first(where: { $0.value?.boolValue == true }),
                  let falseNode = config.nodes.first(where: { $0.value?.boolValue == false }) else {
                throw MokelayRuntimeError.invalidController(config.uuid)
            }

            return inputs["value"]?.isTruthy == true ? trueNode : falseNode
        }

        throw MokelayRuntimeError.unsupportedAction(config.action)
    }

    private func normalizeOutputs(_ outputs: [String: JSONValue], declaredOutputs: [String]) -> [String: JSONValue] {
        guard !declaredOutputs.isEmpty else {
            return outputs
        }

        return declaredOutputs.reduce(into: [String: JSONValue]()) { result, key in
            if let value = outputs[key] {
                result[key] = value
            }
        }
    }

    private func normalizedNextAction(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}
