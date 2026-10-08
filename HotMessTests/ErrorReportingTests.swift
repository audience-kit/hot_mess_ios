//
//  ErrorReportingTests.swift
//  HotMessTests
//

import Foundation
import Testing

@testable import HotMess

@Suite("Error reports")
struct ErrorReportingTests {
    @Test("A crash names what killed the app and keeps its own build")
    func crashReport() {
        let report = ErrorReporter.crashReport(
            exceptionType: 1,
            exceptionCode: 2,
            signal: 11,
            terminationReason: "Namespace SIGNAL, Code 11",
            stack: "{}",
            version: nil,
            build: "403100",
            osVersion: "iPhone OS 26.1",
            device: "iPhone17,1"
        )

        #expect(report.kind == "crash")
        #expect(report.message == "Crash: exception 1, code 2, signal 11, Namespace SIGNAL, Code 11")
        #expect(report.build == "403100")
        #expect(report.app == "ios")
    }

    @Test("Only failures that point at a bug are sent")
    func reportable() {
        #expect(APIError.decoding("keyNotFound").isReportable)
        #expect(APIError.server(status: 500).isReportable)
        #expect(!APIError.server(status: 429).isReportable)
        #expect(!APIError.offline.isReportable)
        #expect(!APIError.unauthorized.isReportable)
        #expect(!APIError.notFound.isReportable)
    }

    @Test("GraphQL failures are named by their operation")
    func operationName() {
        #expect(HotMessAPI.operationName("\n  query Venue($id: ID!) {\n venue { id } }") == "graphql query Venue")
        #expect(HotMessAPI.operationName("{ me { id } }") == "graphql")
    }

    @Test("Reports encode with the API's snake_case keys")
    func encoding() throws {
        let report = ErrorReporter.Report(kind: "error", message: "boom", osVersion: "iOS 26.1")
        let json = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(report)) as? [String: Any]
        )

        #expect(json["os_version"] as? String == "iOS 26.1")
        #expect(json["app"] as? String == "ios")

        let bug = BugReportRequest(
            description: "Map is blank",
            version: "2.0",
            build: "403134",
            osVersion: "iOS 26.1",
            device: "iPhone17,1",
            diagnostics: .init(signedIn: true, environment: "production", locale: "Seattle", recentErrors: [])
        )
        let bugJSON = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(bug)) as? [String: Any]
        )
        let diagnostics = try #require(bugJSON["diagnostics"] as? [String: Any])

        #expect(bugJSON["description"] as? String == "Map is blank")
        #expect(diagnostics["signed_in"] as? Bool == true)
        #expect(diagnostics["recent_errors"] as? [Any] != nil)
    }
}
