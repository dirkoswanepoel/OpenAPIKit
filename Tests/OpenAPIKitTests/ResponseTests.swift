//
//  ResponseTests.swift
//  OpenAPI
//
//  Created by Mathew Polzin on 7/5/19.
//

import Foundation
import XCTest
import OpenAPIKit

final class ResponseTests: XCTestCase {
    func test_Initialization() {
        let r1 = OpenAPI.Response(description: "hello world",
                                  content: [:])
        XCTAssertEqual(r1.description, "hello world")
        XCTAssertNil(r1.headers)
        XCTAssertEqual(r1.content, [:])

        let content = OpenAPI.Content(schema: .init(JSONReference<OpenAPI.Components, JSONSchema>.external("hello.yml")))
        let header = OpenAPI.Header(schemaOrContent: .init(.header(.string)))
        let r2 = OpenAPI.Response(description: "",
                                  headers: ["hello": .init(header)],
                                  content: [.json: content])
        XCTAssertEqual(r2.description, "")
        XCTAssertEqual(r2.headers?["hello"]?.b, header)
        XCTAssertEqual(r2.content, [.json: content])
    }

    func test_responseMap() {
        let responseMap: OpenAPI.Response.Map = [
            200: .response(description: "hello world", content: [:]),
            404: .response(reference: .external("hello.json#/world"))
        ]

        XCTAssertNotNil(responseMap[200]?.b)
        XCTAssertNil(responseMap[200]?.a)
        XCTAssertNotNil(responseMap[404]?.a)
        XCTAssertNil(responseMap[404]?.b)
    }
}

// MARK: Response Status Code
extension ResponseTests {
    func test_defaultFromString() {
        typealias StatusCode = OpenAPI.Response.StatusCode
        XCTAssertEqual(StatusCode(rawValue: "default"), .default)
        XCTAssertEqual(StatusCode(rawValue: "default")?.rawValue, "default")
    }

    func test_codeFromString() {
        typealias StatusCode = OpenAPI.Response.StatusCode
        XCTAssertEqual(StatusCode(rawValue: "123"), .status(code: 123))
        XCTAssertEqual(StatusCode(rawValue: "123")?.rawValue, "123")
        XCTAssertEqual(StatusCode(rawValue: "404"), .status(code: 404))
        XCTAssertEqual(StatusCode(rawValue: "404")?.rawValue, "404")
        XCTAssertEqual(StatusCode(rawValue: "500"), .status(code: 500))
        XCTAssertEqual(StatusCode(rawValue: "500")?.rawValue, "500")
    }

    func test_NilForNonIntegerString() {
        typealias StatusCode = OpenAPI.Response.StatusCode
        XCTAssertNil(StatusCode(rawValue: "hello"))
    }

    func test_codeFromIntegerLiteral() {
        typealias StatusCode = OpenAPI.Response.StatusCode
        XCTAssertEqual(123, StatusCode.status(code: 123))
        XCTAssertEqual(404, StatusCode.status(code: 404))
        XCTAssertEqual(500, StatusCode.status(code: 500))
    }
}

// MARK: - Codable
extension ResponseTests {
    func test_emptyDescriptionEmptyContent_encode() {
        let response = OpenAPI.Response(description: "", content: [:])
        let encodedResponse = try! testStringFromEncoding(of: response)

        assertJSONEquivalent(encodedResponse,
"""
{
  "description" : ""
}
"""
                       )

        let response2 = OpenAPI.Response(description: "", headers: [:], content: [:])
        let encodedResponse2 = try! testStringFromEncoding(of: response2)

        assertJSONEquivalent(encodedResponse2,
"""
{
  "description" : "",
  "headers" : {

  }
}
"""
        )
    }

    func test_emptyDescriptionEmptyContent_decode() {
        let responseData =
"""
{
  "description" : ""
}
""".data(using: .utf8)!
        let response = try! testDecoder.decode(OpenAPI.Response.self, from: responseData)

        XCTAssertEqual(response, OpenAPI.Response(description: "", content: [:]))

        let responseData2 =
"""
{
  "content": {},
  "description" : ""
}
""".data(using: .utf8)!
        let response2 = try! testDecoder.decode(OpenAPI.Response.self, from: responseData2)

        XCTAssertEqual(response2, OpenAPI.Response(description: "", content: [:]))

        let responseData3 =
            """
{
  "content": {},
  "description" : "",
  "headers": {}
}
""".data(using: .utf8)!
        let response3 = try! testDecoder.decode(OpenAPI.Response.self, from: responseData3)

        XCTAssertEqual(response3, OpenAPI.Response(description: "", headers: [:], content: [:]))
    }

    func test_populatedDescriptionPopulatedContent_encode() {
        let content = OpenAPI.Content(schema: .init(.string))
        let header = OpenAPI.Header(schemaOrContent: .init(.header(.string)))
        let response = OpenAPI.Response(description: "hello world",
                                        headers: ["hello": .init(header)],
                                        content: [.json: content])

        let encodedResponse = try! testStringFromEncoding(of: response)

        assertJSONEquivalent(encodedResponse,
"""
{
  "content" : {
    "application\\/json" : {
      "schema" : {
        "type" : "string"
      }
    }
  },
  "description" : "hello world",
  "headers" : {
    "hello" : {
      "schema" : {
        "type" : "string"
      }
    }
  }
}
"""
                       )
    }

    func test_populatedDescriptionPopulatedContent_decode() throws {
        let responseData =
"""
{
    "description": "hello world",
    "content": { "application/json": { "schema": { "type": "string" } } },
    "headers": {
        "hello": { "schema" : { "type" : "string" } }
    }
}
""".data(using: .utf8)!

        let response = try testDecoder.decode(OpenAPI.Response.self, from: responseData)

        let content = OpenAPI.Content(schema: .init(.string(required: false)))
        let header = OpenAPI.Header(schemaOrContent: .init(.header(.string(required: false))))
        XCTAssertEqual(response, OpenAPI.Response(description: "hello world",
                                                  headers: ["hello": .init(header)],
                                                  content: [.json: content]))
    }
}

// MARK: Response Status Code
extension ResponseTests {

    struct StatusCodeWrapper: Codable, Equatable {
        let status: OpenAPI.Response.StatusCode
    }

    func test_defaultStatusCode_encode() throws {
        let status = StatusCodeWrapper(status: .default)
        let encodedStatus = try testStringFromEncoding(of: status)

        assertJSONEquivalent(encodedStatus,
"""
{
  "status" : "default"
}
"""
                       )
    }

    func test_defaultStatusCode_decode() throws {
        let statusCodeData =
"""
{
    "status": "default"
}
""".data(using: .utf8)!

        XCTAssertEqual(try testDecoder.decode(StatusCodeWrapper.self, from: statusCodeData), StatusCodeWrapper(status: .default))
    }

    func test_numberStatusCode_encode() throws {
        let status = StatusCodeWrapper(status: 123)
        let encodedStatus = try testStringFromEncoding(of: status)

        assertJSONEquivalent(encodedStatus,
"""
{
  "status" : "123"
}
"""
        )
    }

    func test_numberStatusCode_decode() throws {
        let statusCodeData =
"""
{
    "status": "123"
}
""".data(using: .utf8)!

        XCTAssertEqual(try testDecoder.decode(StatusCodeWrapper.self, from: statusCodeData), StatusCodeWrapper(status: 123))
    }

    func test_nonesenseStatusCode_decode_throws() {
        let statusCodeData =
"""
{
    "status": "hello world"
}
""".data(using: .utf8)!

        XCTAssertThrowsError(try testDecoder.decode(StatusCodeWrapper.self, from: statusCodeData))
    }
}
