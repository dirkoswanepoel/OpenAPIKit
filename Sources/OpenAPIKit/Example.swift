//
//  Example.swift
//  
//
//  Created by Mathew Polzin on 10/6/19.
//

import Foundation
import Poly
import OrderedDictionary
import AnyCodable

extension OpenAPI {
    public struct Example: Equatable, CodableVendorExtendable {
        public let summary: String?
        public let description: String?
        /// Represents the OpenAPI `externalValue` as a URL _or_
        /// the OpenAPI `value` as `AnyCodable`
        public let value: Either<URL, AnyCodable>

        /// Dictionary of vendor extensions.
        ///
        /// These should be of the form:
        /// `[ "x-extensionKey": <anything>]`
        /// where the values are anything codable.
        public let vendorExtensions: [String: AnyCodable]

        public init(summary: String? = nil,
                    description: String? = nil,
                    value: Either<URL, AnyCodable>,
                    vendorExtensions: [String: AnyCodable] = [:]) {
            self.summary = summary
            self.description = description
            self.value = value
            self.vendorExtensions = vendorExtensions
        }
    }
}

extension OpenAPI.Example {
    public typealias Map = OrderedDictionary<String, Either<JSONReference<OpenAPI.Components, OpenAPI.Example>, OpenAPI.Example>>
}

// MARK: - Either Convenience
extension Either where A == JSONReference<OpenAPI.Components, OpenAPI.Example>, B == OpenAPI.Example {
    public static func example(
        summary: String? = nil,
        description: String? = nil,
        value: Either<URL, AnyCodable>,
        vendorExtensions: [String: AnyCodable] = [:]
    ) -> Self {
        return .b(
            .init(
                summary: summary,
                description: description,
                value: value,
                vendorExtensions: vendorExtensions
            )
        )
    }

    public static func example(reference: JSONReference<OpenAPI.Components, OpenAPI.Example>) -> Self {
        return .a(reference)
    }
}

// MARK: - Codable
extension OpenAPI.Example: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try summary.encodeIfNotNil(to: &container, forKey: .summary)

        try description.encodeIfNotNil(to: &container, forKey: .description)

        switch value {
        case .a(let url):
            try container.encode(url, forKey: .externalValue)
        case .b(let example):
            try container.encode(example, forKey: .value)
        }

        try encodeExtensions(to: &container)
    }
}

extension OpenAPI.Example: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        guard !(container.contains(.externalValue) && container.contains(.value)) else {
            throw Error.foundBothInternalAndExternalExamples
        }

        let externalValue = try container.decodeIfPresent(URL.self, forKey: .externalValue)

        summary = try container.decodeIfPresent(String.self, forKey: .summary)

        description = try container.decodeIfPresent(String.self, forKey: .description)

        value = try externalValue.map(Either.init)
            ?? .init( container.decode(AnyCodable.self, forKey: .value))

        vendorExtensions = try Self.extensions(from: decoder)
    }

    public enum Error: Swift.Error {
        case foundBothInternalAndExternalExamples
    }
}

extension OpenAPI.Example {
    enum CodingKeys: ExtendableCodingKey {
        case summary
        case description
        case value
        case externalValue
        case extended(String)

        static var allBuiltinKeys: [CodingKeys] {
            return [.summary, .description, .value, .externalValue]
        }

        static func extendedKey(for value: String) -> CodingKeys {
            return .extended(value)
        }

        init?(stringValue: String) {
            switch stringValue {
            case "summary":
                self = .summary
            case "description":
                self = .description
            case "value":
                self = .value
            case "externalValue":
                self = .externalValue
            default:
                self = .extendedKey(for: stringValue)
            }
        }

        init?(intValue: Int) {
            return nil
        }

        var stringValue: String {
            switch self {
            case .summary:
                return "summary"
            case .description:
                return "description"
            case .value:
                return "value"
            case .externalValue:
                return "externalValue"
            case .extended(let key):
                return key
            }
        }

        var intValue: Int? {
            return nil
        }
    }
}
