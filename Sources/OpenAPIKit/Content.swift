//
//  Content.swift
//  OpenAPIKit
//
//  Created by Mathew Polzin on 7/4/19.
//

import Foundation
import Poly
import OrderedDictionary
import AnyCodable

extension OpenAPI {
    public struct Content: Equatable, CodableVendorExtendable {
        public var schema: Either<JSONReference<Components, JSONSchema>, JSONSchema>
        public var example: AnyCodable?
        public var examples: Example.Map?
        public var encoding: OrderedDictionary<String, Encoding>?

        /// Dictionary of vendor extensions.
        ///
        /// These should be of the form:
        /// `[ "x-extensionKey": <anything>]`
        /// where the values are anything codable.
        public var vendorExtensions: [String: AnyCodable]

        public init(schema: Either<JSONReference<Components, JSONSchema>, JSONSchema>,
                    example: AnyCodable? = nil,
                    encoding: OrderedDictionary<String, Encoding>? = nil,
                    vendorExtensions: [String: AnyCodable] = [:]) {
            self.schema = schema
            self.example = example
            self.examples = nil
            self.encoding = encoding
            self.vendorExtensions = vendorExtensions
        }

        public init(schemaReference: JSONReference<Components, JSONSchema>,
                    example: AnyCodable? = nil,
                    encoding: OrderedDictionary<String, Encoding>? = nil,
                    vendorExtensions: [String: AnyCodable] = [:]) {
            self.schema = .init(schemaReference)
            self.example = example
            self.examples = nil
            self.encoding = encoding
            self.vendorExtensions = vendorExtensions
        }

        public init(schema: JSONSchema,
                    example: AnyCodable? = nil,
                    encoding: OrderedDictionary<String, Encoding>? = nil,
                    vendorExtensions: [String: AnyCodable] = [:]) {
            self.schema = .init(schema)
            self.example = example
            self.examples = nil
            self.encoding = encoding
            self.vendorExtensions = vendorExtensions
        }

        public init(schema: Either<JSONReference<Components, JSONSchema>, JSONSchema>,
                    examples: Example.Map?,
                    encoding: OrderedDictionary<String, Encoding>? = nil,
                    vendorExtensions: [String: AnyCodable] = [:]) {
            self.schema = schema
            self.examples = examples
            self.example = examples.flatMap(Self.firstExample(from:))
            self.encoding = encoding
            self.vendorExtensions = vendorExtensions
        }

        public init(schemaReference: JSONReference<Components, JSONSchema>,
                    examples: Example.Map?,
                    encoding: OrderedDictionary<String, Encoding>? = nil,
                    vendorExtensions: [String: AnyCodable] = [:]) {
            self.schema = .init(schemaReference)
            self.examples = examples
            self.example = examples.flatMap(Self.firstExample(from:))
            self.encoding = encoding
            self.vendorExtensions = vendorExtensions
        }

        public init(schema: JSONSchema,
                    examples: Example.Map?,
                    encoding: OrderedDictionary<String, Encoding>? = nil,
                    vendorExtensions: [String: AnyCodable] = [:]) {
            self.schema = .init(schema)
            self.examples = examples
            self.example = examples.flatMap(Self.firstExample(from:))
            self.encoding = encoding
            self.vendorExtensions = vendorExtensions
        }
    }
}

extension OpenAPI.Content {
    public typealias Map = OrderedDictionary<OpenAPI.ContentType, OpenAPI.Content>
}

extension OpenAPI.Content {
    internal static func firstExample(from exampleDict: OpenAPI.Example.Map) -> AnyCodable? {
        return exampleDict
            .sorted { $0.key < $1.key }
            .compactMap { $0.value.b?.value.b }
            .first
    }
}

// MARK: - Codable

extension OpenAPI.Content: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(schema, forKey: .schema)

        // only encode `examples` if non-nil,
        // otherwise encode `example` if non-nil
        if examples != nil {
            try container.encode(examples, forKey: .examples)
        } else if example != nil {
            try container.encode(example, forKey: .example)
        }

        try encoding.encodeIfNotNil(to: &container, forKey: .encoding)

        try encodeExtensions(to: &container)
    }
}

extension OpenAPI.Content: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        guard !(container.contains(.examples) && container.contains(.example)) else {
            throw InconsistencyError(
                subjectName: "Example and Examples",
                details: "Only one of `example` and `examples` is allowed in the Media Type Object (`OpenAPI.Content`).",
                codingPath: container.codingPath
            )
        }

        schema = try container.decode(Either<JSONReference<OpenAPI.Components, JSONSchema>, JSONSchema>.self, forKey: .schema)

        encoding = try container.decodeIfPresent(OrderedDictionary<String, Encoding>.self, forKey: .encoding)

        if container.contains(.example) {
            example = try container.decode(AnyCodable.self, forKey: .example)
            examples = nil
        } else {
            let examplesMap = try container.decodeIfPresent(OpenAPI.Example.Map.self, forKey: .examples)
            examples = examplesMap
            example = examplesMap.flatMap(Self.firstExample(from:))
        }

        vendorExtensions = try Self.extensions(from: decoder)
    }
}

extension OpenAPI.Content {
    enum CodingKeys: ExtendableCodingKey {
        case schema
        case example
        case examples // `example` and `examples` are mutually exclusive
        case encoding
        case extended(String)

        static var allBuiltinKeys: [CodingKeys] {
            return [.schema, .example, .examples, .encoding]
        }

        static func extendedKey(for value: String) -> CodingKeys {
            return .extended(value)
        }

        init?(stringValue: String) {
            switch stringValue {
            case "schema":
                self = .schema
            case "example":
                self = .example
            case "examples":
                self = .examples
            case "encoding":
                self = .encoding
            default:
                self = .extendedKey(for: stringValue)
            }
        }

        init?(intValue: Int) {
            return nil
        }

        var stringValue: String {
            switch self {
            case .schema:
                return "schema"
            case .example:
                return "example"
            case .examples:
                return "examples"
            case .encoding:
                return "encoding"
            case .extended(let key):
                return key
            }
        }

        var intValue: Int? {
            return nil
        }
    }
}
