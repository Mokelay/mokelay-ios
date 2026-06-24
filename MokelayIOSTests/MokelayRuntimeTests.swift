import XCTest
@testable import MokelayIOS

final class MokelayRuntimeTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.handler = nil
        super.tearDown()
    }

    func testTargetPageDSLDecodesBlocksAndEvents() throws {
        let listPage = try decodeFixturePage("mokelay_list_page")
        let createPage = try decodeFixturePage("mokelay_create_page")

        XCTAssertEqual(listPage.uuid, "mokelay_list_page")
        XCTAssertEqual(listPage.blocks.map(\.type), ["MButton", "MAdvanceTable"])
        XCTAssertEqual(listPage.blocks[0].events.first?.actions.first?.action, "open_dialog")
        XCTAssertEqual(listPage.blocks[1].events, [])

        XCTAssertEqual(createPage.uuid, "mokelay_create_page")
        XCTAssertEqual(createPage.blocks.map(\.type), ["MForm", "MButton"])
        XCTAssertEqual(createPage.blocks[1].events.first?.actions.map(\.action), ["confirm", "if_controller", "execute_ds", "call_block_method"])
    }

    func testTemplateResolverAndTrimProcessor() throws {
        let sourceBlock = MokelayBlock(
            id: "button",
            type: "MButton",
            data: [
                "action": .object([
                    "uuid": .string("page-1"),
                    "name": .string("页面")
                ])
            ]
        )
        var state = MokelayActionState(sourceBlock: sourceBlock)
        state.actions["confirm"] = MokelayActionRecord(inputs: [:], outputs: ["result": .bool(true)])

        let content = try MokelayTemplateResolver.resolve(
            .object(["template": .string("删除 {{sourceBlock.data.action.name}}")]),
            state: state
        )
        let routed = try MokelayTemplateResolver.resolve(
            .object(["template": .string("{{actions['confirm'].outputs.result}}")]),
            state: state
        )
        let trimmed = try MokelayProcessors.apply(.string("  hello  "), processors: [.string("trim")])

        XCTAssertEqual(content, .string("删除 页面"))
        XCTAssertEqual(routed, .bool(true))
        XCTAssertEqual(trimmed, .string("hello"))
    }

    func testDatasourceURLBodyAndSchemaSelection() throws {
        let tableDatasource = MokelayDatasource(value: .object([
            "type": .string("API"),
            "domain": .string("mokelay"),
            "path": .string("/api/mokelay/list_pages"),
            "method": .string("GET"),
            "queryData": .array([
                .object(["key": .string("page"), "value": .object(["mode": .string("variable"), "blockId": .string("table"), "variable": .string("page")])]),
                .object(["key": .string("pageSize"), "value": .object(["mode": .string("variable"), "blockId": .string("table"), "variable": .string("pageSize")])])
            ])
        ]))!
        let apiClient = MokelayPageAPI(baseURL: URL(string: "http://127.0.0.1:8787")!)
        let url = try MokelayDatasourceRuntime.requestURL(
            for: tableDatasource,
            apiClient: apiClient,
            blocks: ["table": ["page": .number(2), "pageSize": .number(20)]]
        )

        XCTAssertEqual(url.path, "/api/mokelay/list_pages")
        XCTAssertEqual(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "page" })?.value, "2")
        XCTAssertEqual(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "pageSize" })?.value, "20")

        let createDatasource = MokelayDatasource(value: .object([
            "type": .string("API"),
            "domain": .string("mokelay"),
            "path": .string("/api/mokelay/create_page"),
            "method": .string("POST"),
            "bodyData": .array([
                .object([
                    "key": .string("name"),
                    "dataType": .string("string"),
                    "value": .object([
                        "mode": .string("variable"),
                        "blockId": .string("form"),
                        "variable": .string("name"),
                        "processors": .array([.string("trim")])
                    ])
                ]),
                .object(["key": .string("blocks"), "dataType": .string("array"), "value": .array([])])
            ])
        ]))!
        let body = try MokelayDatasourceRuntime.requestBody(
            for: createDatasource,
            blocks: ["form": ["name": .string("  New Page  ")]]
        )

        XCTAssertEqual(body?["name"], .string("New Page"))
        XCTAssertEqual(body?["blocks"], .array([]))

        let rawResponse: JSONValue = .object([
            "data": .object([
                "pages": .array([.object(["uuid": .string("index")])]),
                "pagination": .object(["page": .number(1)])
            ])
        ])
        XCTAssertEqual(rawResponse.value(atPath: "data.pages[]"), .array([.object(["uuid": .string("index")])]))
        XCTAssertEqual(rawResponse.value(atPath: "data.pagination.page"), .number(1))
    }

    func testDatasourceRuntimeExecutesListPagesRequest() async throws {
        let apiClient = mockAPIClient { request in
            XCTAssertEqual(request.url?.path, "/api/mokelay/list_pages")
            let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
            XCTAssertEqual(components?.queryItems?.first(where: { $0.name == "page" })?.value, "1")
            XCTAssertEqual(components?.queryItems?.first(where: { $0.name == "pageSize" })?.value, "10")
            return .success(.object([
                "ok": .bool(true),
                "data": .object([
                    "pages": .array([.object(["uuid": .string("index"), "name": .string("首页")])]),
                    "pagination": .object([
                        "page": .number(1),
                        "pageSize": .number(10),
                        "total": .number(1)
                    ])
                ])
            ]))
        }
        let datasource = MokelayDatasource(value: .object([
            "type": .string("API"),
            "domain": .string("mokelay"),
            "path": .string("/api/mokelay/list_pages"),
            "method": .string("GET"),
            "queryData": .array([
                .object(["key": .string("page"), "value": .object(["mode": .string("variable"), "blockId": .string("table"), "variable": .string("page")])]),
                .object(["key": .string("pageSize"), "value": .object(["mode": .string("variable"), "blockId": .string("table"), "variable": .string("pageSize")])])
            ]),
            "schemaSelections": .array([
                .object(["path": .string("data.pages[]"), "type": .string("array"), "label": .string("页面列表")])
            ]),
            "matchingExternalFields": .array([
                .object(["label": .string("列表数据"), "variable": .string("data"), "matchFieldPath": .string("data.pages[]")])
            ])
        ]))!

        let result = try await MokelayDatasourceRuntime.execute(
            datasource: datasource,
            apiClient: apiClient,
            blocks: ["table": ["page": .number(1), "pageSize": .number(10)]]
        )

        XCTAssertEqual(result.matchingExternalFieldData["data"], .array([.object(["uuid": .string("index"), "name": .string("首页")])]))
    }

    @MainActor
    func testActionGraphDeleteExecutesDatasourceThenRefreshesTable() async throws {
        var didRefresh = false
        var capturedBody: JSONValue?
        let apiClient = mockAPIClient { request in
            XCTAssertEqual(request.url?.path, "/api/mokelay/delete_page_by_uuid")
            capturedBody = try? JSONDecoder().decode(JSONValue.self, from: requestBodyData(request))
            return .success(.object(["ok": .bool(true), "data": .object(["affected": .number(1)])]))
        }
        let runtime = MokelayRuntime(apiClient: apiClient)
        runtime.register(MokelayBlockRuntimeHandle(
            id: "table",
            type: "MAdvanceTable",
            getData: { ["page": .number(1), "pageSize": .number(10), "total": .number(1), "data": .array([])] },
            callMethod: { methodName, _ in
                if methodName == "refresh" {
                    didRefresh = true
                    return .object(["ok": .bool(true)])
                }
                return nil
            }
        ))
        let sourceBlock = MokelayBlock(
            id: "delete",
            type: "MButton",
            data: ["action": .object(["uuid": .string("page-1")])]
        )
        let actions = [
            MokelayActionConfig(
                uuid: "delete_ds",
                action: "execute_ds",
                inputs: [
                    "dsConfig": .object([
                        "type": .string("API"),
                        "domain": .string("mokelay"),
                        "path": .string("/api/mokelay/delete_page_by_uuid"),
                        "method": .string("POST"),
                        "bodyData": .array([
                            .object([
                                "key": .string("uuid"),
                                "dataType": .string("string"),
                                "value": .object(["template": .string("{{sourceBlock.data.action.uuid}}")])
                            ])
                        ])
                    ])
                ],
                outputs: ["rawResponse"],
                nextAction: "refresh"
            ),
            MokelayActionConfig(
                uuid: "refresh",
                action: "call_block_method",
                inputs: [
                    "blockId": .string("table"),
                    "method": .string("refresh")
                ],
                outputs: ["returnData"]
            )
        ]

        try await runtime.runActionGraph(actions, sourceBlock: sourceBlock)

        XCTAssertEqual(capturedBody?["uuid"], .string("page-1"))
        XCTAssertTrue(didRefresh)
    }

    func testPreviewURLParsesSystemSourceAndAppRoute() {
        let systemDestination = extractPageDestination(from: "http://localhost:5173/#/pages/mokelay_list_page/preview?source=system")
        let appRouteDestination = extractPageDestination(from: "/#/pages/index")

        XCTAssertEqual(systemDestination, PageDestination(uuid: "mokelay_list_page", source: .system))
        XCTAssertEqual(appRouteDestination, PageDestination(uuid: "index", source: .user))
    }

    func testManualPageDestinationUsesSystemCheckbox() {
        XCTAssertEqual(
            manualPageDestination(uuid: " mokelay_list_page ", isSystemPage: true),
            PageDestination(uuid: "mokelay_list_page", source: .system)
        )
        XCTAssertEqual(
            manualPageDestination(uuid: "index", isSystemPage: false),
            PageDestination(uuid: "index", source: .user)
        )
    }

    private func decodeFixturePage(_ uuid: String) throws -> MokelayPage {
        let testFile = URL(fileURLWithPath: #filePath)
        let fixture = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("mokelay-server/server/assets/mokelay-pages/\(uuid).json")
        let data = try Data(contentsOf: fixture)
        return try JSONDecoder().decode(MokelayPage.self, from: data)
    }

    private func mockAPIClient(_ handler: @escaping (URLRequest) throws -> MockURLProtocol.Response) -> MokelayPageAPI {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        MockURLProtocol.handler = handler
        return MokelayPageAPI(
            baseURL: URL(string: "http://127.0.0.1:8787")!,
            session: URLSession(configuration: configuration)
        )
    }
}

private func requestBodyData(_ request: URLRequest) -> Data {
    if let body = request.httpBody {
        return body
    }

    guard let stream = request.httpBodyStream else {
        return Data()
    }

    stream.open()
    defer {
        stream.close()
    }

    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 1024)

    while stream.hasBytesAvailable {
        let count = stream.read(&buffer, maxLength: buffer.count)
        if count <= 0 {
            break
        }
        data.append(buffer, count: count)
    }

    return data
}

final class MockURLProtocol: URLProtocol {
    enum Response {
        case success(JSONValue)
        case failure(Int, JSONValue)
    }

    static var handler: ((URLRequest) throws -> Response)?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let response = try handler(request)
            let statusCode: Int
            let body: JSONValue

            switch response {
            case .success(let value):
                statusCode = 200
                body = value
            case .failure(let status, let value):
                statusCode = status
                body = value
            }

            let data = try JSONEncoder().encode(body)
            let httpResponse = HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
