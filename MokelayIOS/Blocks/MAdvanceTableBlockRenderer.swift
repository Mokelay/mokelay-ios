import SwiftUI

struct MAdvanceTableBlockRenderer: MokelayBlockRenderer {
    let type = "MAdvanceTable"

    func render(block: MokelayBlock, context: RenderContext) -> AnyView {
        AnyView(MAdvanceTableBlockView(block: block, context: context))
    }
}

private struct MAdvanceTableColumn: Identifiable, Equatable {
    let id: String
    let columnName: String
    let width: CGFloat?
    let fixed: String?
    let fieldVariable: String
    let columnContent: [MokelayBlock]

    static func columns(from value: JSONValue?) -> [MAdvanceTableColumn] {
        value?.arrayValue?.enumerated().compactMap { index, item in
            guard let object = item.objectValue else {
                return nil
            }

            let columnName = object["columnName"]?.stringValue ?? ""
            let fieldVariable = object["fieldVariable"]?.stringValue ?? ""

            return MAdvanceTableColumn(
                id: "\(fieldVariable)-\(index)",
                columnName: columnName,
                width: object["width"]?.numberValue.map { CGFloat($0) },
                fixed: object["fixed"]?.stringValue,
                fieldVariable: fieldVariable,
                columnContent: object["columnContent"]?.arrayValue?.compactMap(MokelayBlock.fromJSONValue) ?? []
            )
        } ?? []
    }
}

@MainActor
private final class MAdvanceTableModel: ObservableObject {
    let block: MokelayBlock
    let runtime: MokelayRuntime
    let columns: [MAdvanceTableColumn]
    let datasource: MokelayDatasource?
    let showsIndex: Bool
    let showsSelection: Bool
    let showsPagination: Bool

    @Published var rows: [[String: JSONValue]] = []
    @Published var page = 1
    @Published var pageSize = 10
    @Published var total = 0
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var selectedRows = Set<Int>()

    private var hasLoaded = false

    init(block: MokelayBlock, runtime: MokelayRuntime) {
        self.block = block
        self.runtime = runtime
        self.columns = MAdvanceTableColumn.columns(from: block.data["columns"])
        self.datasource = MokelayDatasource(value: block.data["ds"])
        self.showsIndex = block.data["index"]?.boolValue == true
        self.showsSelection = block.data["selection"]?.boolValue == true
        self.showsPagination = block.data["showPageBreak"]?.boolValue == true
    }

    var totalPages: Int {
        max(1, Int(ceil(Double(max(total, 0)) / Double(max(pageSize, 1)))))
    }

    var currentPage: Int {
        min(max(page, 1), totalPages)
    }

    var paginationStart: Int {
        total > 0 ? (currentPage - 1) * pageSize + 1 : 0
    }

    var paginationEnd: Int {
        total > 0 ? min(currentPage * pageSize, total) : 0
    }

    var paginationSummary: String {
        "第 \(paginationStart)-\(paginationEnd) 条，共 \(total) 条 · 第 \(currentPage) / \(totalPages) 页"
    }

    func register() {
        runtime.register(
            MokelayBlockRuntimeHandle(
                id: block.id,
                type: block.type,
                getData: { [weak self] in
                    await self?.getData() ?? [:]
                },
                callMethod: { [weak self] methodName, _ in
                    guard let self else {
                        return nil
                    }

                    if methodName == "refresh" {
                        return try await self.refresh()
                    }

                    if methodName == "getData" {
                        return .object(await self.getData())
                    }

                    return nil
                }
            )
        )
    }

    func loadIfNeeded() {
        guard !hasLoaded else {
            return
        }

        hasLoaded = true
        Task {
            try? await refresh()
        }
    }

    func refresh() async throws -> JSONValue {
        await loadDatasourceRows()
        return .object(await getData())
    }

    func goToPage(_ targetPage: Int) {
        guard !isLoading else {
            return
        }

        let nextPage = min(max(targetPage, 1), totalPages)
        guard nextPage != currentPage else {
            return
        }

        page = nextPage
        Task {
            try? await refresh()
        }
    }

    func toggleRow(_ index: Int) {
        if selectedRows.contains(index) {
            selectedRows.remove(index)
        } else {
            selectedRows.insert(index)
        }
    }

    func toggleAllRows() {
        if selectedRows.count == rows.count {
            selectedRows = []
        } else {
            selectedRows = Set(rows.indices)
        }
    }

    func getData() async -> [String: JSONValue] {
        [
            "data": .array(rows.map { .object($0) }),
            "page": .number(Double(currentPage)),
            "pageSize": .number(Double(pageSize)),
            "total": .number(Double(total))
        ]
    }

    private func loadDatasourceRows() async {
        selectedRows = []
        errorMessage = ""

        guard let datasource else {
            rows = []
            return
        }

        isLoading = true

        do {
            var blocks = await runtime.getBlockDataContext(excluding: block.id)
            blocks[block.id] = await getData()
            let runtimeData = try await MokelayDatasourceRuntime.execute(
                datasource: datasource,
                apiClient: runtime.apiClient,
                blocks: blocks
            )

            guard let dataValue = runtimeData.matchingExternalFieldData["data"],
                  case .array(let rawRows) = dataValue else {
                rows = []
                errorMessage = "列表数据格式无效"
                isLoading = false
                return
            }

            rows = rawRows.compactMap(\.objectValue)
            page = positiveInteger(runtimeData.matchingExternalFieldData["page"], fallback: 1)
            pageSize = positiveInteger(runtimeData.matchingExternalFieldData["pageSize"], fallback: 10)
            total = nonNegativeInteger(runtimeData.matchingExternalFieldData["total"], fallback: rows.count)
        } catch {
            rows = []
            errorMessage = "数据加载失败"
        }

        isLoading = false
    }

    private func positiveInteger(_ value: JSONValue?, fallback: Int) -> Int {
        let raw = value?.numberValue ?? value?.stringValue.flatMap(Double.init) ?? Double(fallback)
        let normalized = Int(raw)
        return normalized > 0 ? normalized : fallback
    }

    private func nonNegativeInteger(_ value: JSONValue?, fallback: Int) -> Int {
        let raw = value?.numberValue ?? value?.stringValue.flatMap(Double.init) ?? Double(fallback)
        let normalized = Int(raw)
        return normalized >= 0 ? normalized : fallback
    }
}

private struct MAdvanceTableBlockView: View {
    @StateObject private var model: MAdvanceTableModel
    private let context: RenderContext

    init(block: MokelayBlock, context: RenderContext) {
        _model = StateObject(wrappedValue: MAdvanceTableModel(block: block, runtime: context.runtime))
        self.context = context
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(.horizontal, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 0) {
                    headerRow
                    bodyRows
                }
                .background(Color(uiColor: .systemBackground))
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color(uiColor: .separator), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: model.showsPagination ? 0 : 8, style: .continuous))

            if model.showsPagination {
                paginationBar
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            model.register()
            model.loadIfNeeded()
        }
        .onDisappear {
            model.runtime.unregister(id: model.block.id)
        }
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            if model.showsSelection {
                selectionHeaderCell
            }

            if model.showsIndex {
                headerCell("#", width: 56)
            }

            ForEach(model.columns) { column in
                headerCell(column.columnName, width: width(for: column))
            }
        }
    }

    @ViewBuilder
    private var bodyRows: some View {
        if model.isLoading || !model.errorMessage.isEmpty || model.rows.isEmpty {
            emptyRow
        } else {
            ForEach(Array(model.rows.enumerated()), id: \.offset) { rowIndex, row in
                HStack(spacing: 0) {
                    if model.showsSelection {
                        selectionCell(rowIndex)
                    }

                    if model.showsIndex {
                        bodyCell(width: 56) {
                            Text(String(rowIndex + 1))
                                .font(.system(size: 14))
                        }
                    }

                    ForEach(model.columns) { column in
                        bodyCell(width: width(for: column)) {
                            cellContent(row: row, column: column)
                        }
                    }
                }
            }
        }
    }

    private var emptyRow: some View {
        let message = model.isLoading ? "正在加载..." : (!model.errorMessage.isEmpty ? model.errorMessage : "暂无数据")
        return Text(message)
            .font(.system(size: 14))
            .foregroundColor(.secondary)
            .frame(width: tableWidth)
            .frame(minHeight: 52)
            .overlay(horizontalBorder, alignment: .bottom)
    }

    private var paginationBar: some View {
        HStack(spacing: 12) {
            Text(model.paginationSummary)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)

            Spacer(minLength: 12)

            Button("上一页") {
                model.goToPage(model.currentPage - 1)
            }
            .disabled(model.isLoading || model.currentPage <= 1)

            Button("下一页") {
                model.goToPage(model.currentPage + 1)
            }
            .disabled(model.isLoading || model.currentPage >= model.totalPages)
        }
        .buttonStyle(.bordered)
        .padding(12)
        .background(Color(uiColor: .secondarySystemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(uiColor: .separator), lineWidth: 1)
        )
    }

    private var selectionHeaderCell: some View {
        bodyCell(width: 44) {
            Button {
                model.toggleAllRows()
            } label: {
                Image(systemName: model.selectedRows.count == model.rows.count && !model.rows.isEmpty ? "checkmark.square.fill" : "square")
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)
        }
        .background(Color(uiColor: .secondarySystemBackground))
    }

    private func selectionCell(_ rowIndex: Int) -> some View {
        bodyCell(width: 44) {
            Button {
                model.toggleRow(rowIndex)
            } label: {
                Image(systemName: model.selectedRows.contains(rowIndex) ? "checkmark.square.fill" : "square")
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)
        }
    }

    private func headerCell(_ text: String, width: CGFloat) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.secondary)
            .lineLimit(1)
            .frame(width: width, alignment: .leading)
            .frame(minHeight: 42)
            .padding(.horizontal, 12)
            .background(Color(uiColor: .secondarySystemBackground))
            .overlay(verticalBorder, alignment: .trailing)
            .overlay(horizontalBorder, alignment: .bottom)
    }

    private func bodyCell<Content: View>(width: CGFloat, @ViewBuilder content: () -> Content) -> some View {
        content()
            .font(.system(size: 14))
            .lineLimit(1)
            .frame(width: width, alignment: .leading)
            .frame(minHeight: 48)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(uiColor: .systemBackground))
            .overlay(verticalBorder, alignment: .trailing)
            .overlay(horizontalBorder, alignment: .bottom)
    }

    @ViewBuilder
    private func cellContent(row: [String: JSONValue], column: MAdvanceTableColumn) -> some View {
        HStack(spacing: 6) {
            ForEach(cellBlocks(row: row, column: column)) { block in
                if block.type == "paragraph" {
                    Text(block.stringData("text")?.mokelayPlainTextFromHTML() ?? "")
                        .font(.system(size: 14))
                        .lineLimit(1)
                } else {
                    context.registry.render(block: block, context: context.compact())
                }
            }
        }
    }

    private var verticalBorder: some View {
        Rectangle()
            .fill(Color(uiColor: .separator))
            .frame(width: 1)
    }

    private var horizontalBorder: some View {
        Rectangle()
            .fill(Color(uiColor: .separator))
            .frame(height: 1)
    }

    private var tableWidth: CGFloat {
        let selectionWidth: CGFloat = model.showsSelection ? 44 : 0
        let indexWidth: CGFloat = model.showsIndex ? 56 : 0
        return selectionWidth + indexWidth + model.columns.reduce(CGFloat(0)) { $0 + width(for: $1) }
    }

    private func width(for column: MAdvanceTableColumn) -> CGFloat {
        if let width = column.width, width > 0 {
            return width
        }

        if column.fieldVariable == "uuid" {
            return 300
        }

        if column.fieldVariable.contains("created") || column.fieldVariable.contains("updated") {
            return 240
        }

        if column.fieldVariable == "action" {
            return 168
        }

        return 180
    }

    private func cellBlocks(row: [String: JSONValue], column: MAdvanceTableColumn) -> [MokelayBlock] {
        column.columnContent.map { block in
            if block.type == "paragraph" {
                let text = block.stringData("text") ?? ""
                var data = block.data
                data["text"] = .string(MokelayTemplateResolver.interpolateString(text, row: row))
                return MokelayBlock(id: block.id, type: block.type, data: data, events: block.events)
            }

            return MokelayBlock(
                id: block.id,
                type: block.type,
                data: block.data.mapValues { MokelayTemplateResolver.interpolateJSON($0, row: row) },
                events: block.events
            )
        }
    }
}
