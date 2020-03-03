//
//  SchemaObjectContext.swift
//  
//
//  Created by Mathew Polzin on 6/22/19.
//

import Foundation
import AnyCodable
import Poly

// MARK: - Generic Context

public protocol JSONSchemaContext {
    var required: Bool { get }
    var nullable: Bool { get }
    var title: String? { get }
    var description: String? { get }
    var externalDocs: OpenAPI.ExternalDoc? { get }
    var allowedValues: [AnyCodable]? { get }
    var example: String? { get }
    var readOnly: Bool { get }
    var writeOnly: Bool { get }
    var deprecated: Bool { get }
}

extension JSONSchema {
    public struct Context<Format: OpenAPIFormat>: JSONSchemaContext, Equatable {
        public let format: Format
        public let required: Bool // default true (except on decode, where required depends on whether there is a parent schema scope to contain a 'required' property)
        public let nullable: Bool // default false

        public let permissions: Permissions // default `.readWrite`
        public let deprecated: Bool // default false

        public let title: String?
        public let description: String?
        public let externalDocs: OpenAPI.ExternalDoc?

        // NOTE: "const" is supported by the newest JSON Schema spec but not
        // yet by OpenAPI. Instead, will use "enum" with one possible value for now.
//        public let constantValue: Format.SwiftType?

        /// The OpenAPI spec calls this "enum"
        ///
        /// If not specified, it is assumed that any
        /// value of the given format is allowed.
        /// NOTE: I would like the array of allowed
        /// values to have the type `Format.SwiftType`
        /// but this is not tractable because I also
        /// want to be able to automatically turn any
        /// Swift type that will get _encoded as
        /// something compatible with_ `Format.SwiftType`
        /// into an allowed value.
        public let allowedValues: [AnyCodable]?

        // I wanted example to be AnyCodable, but alas that causes
        // runtime problems when encoding in a very strange way.
        // For now, a String (which is OK by the OpenAPI spec) will
        // have to do.
        public let example: String?

        public var readOnly: Bool { permissions == .readOnly }
        public var writeOnly: Bool { permissions == .writeOnly }

        public init<T: Encodable>(format: Format = .unspecified,
                                  required: Bool = true,
                                  nullable: Bool = false,
                                  permissions: Permissions = .readWrite,
                                  deprecated: Bool = false,
                                  title: String? = nil,
                                  description: String? = nil,
                                  externalDocs: OpenAPI.ExternalDoc? = nil,
                                  allowedValues: [AnyCodable]? = nil,
                                  example: (codable: T, encoder: JSONEncoder)) {
            self.format = format
            self.required = required
            self.nullable = nullable
            self.permissions = permissions
            self.deprecated = deprecated
            self.title = title
            self.description = description
            self.externalDocs = externalDocs
            self.allowedValues = allowedValues
            self.example = (try? example.encoder.encode(example.codable))
                .flatMap { String(data: $0, encoding: .utf8) }
                ?? JSONSchema.fragmentString(from: example.codable)
        }

        public init(format: Format = .unspecified,
                    required: Bool = true,
                    nullable: Bool = false,
                    permissions: Permissions = .readWrite,
                    deprecated: Bool = false,
                    title: String? = nil,
                    description: String? = nil,
                    externalDocs: OpenAPI.ExternalDoc? = nil,
                    allowedValues: [AnyCodable]? = nil,
                    example: (codable: AnyCodable, encoder: JSONEncoder)? = nil) {
            self.format = format
            self.required = required
            self.nullable = nullable
            self.permissions = permissions
            self.deprecated = deprecated
            self.title = title
            self.description = description
            self.externalDocs = externalDocs
            self.allowedValues = allowedValues
            self.example = example
                .flatMap { try? $0.encoder.encode($0.codable)}
                .flatMap { String(data: $0, encoding: .utf8) }
        }

        private init(format: Format = .unspecified,
                     required: Bool = true,
                     nullable: Bool = false,
                     permissions: Permissions = .readWrite,
                     deprecated: Bool = false,
                     title: String? = nil,
                     description: String? = nil,
                     externalDocs: OpenAPI.ExternalDoc? = nil,
                     allowedValues: [AnyCodable]? = nil,
                     example: String?) {
            self.format = format
            self.required = required
            self.nullable = nullable
            self.permissions = permissions
            self.deprecated = deprecated
            self.title = title
            self.description = description
            self.externalDocs = externalDocs
            self.allowedValues = allowedValues
            self.example = example
        }

        public enum Permissions: String, Codable {
            case readOnly
            case writeOnly
            case readWrite
        }
    }
}

// MARK: - Transformations

extension JSONSchema.Context {
    /// Return the optional version of this Context
    public func optionalContext() -> JSONSchema.Context<Format> {
        return .init(format: format,
                     required: false,
                     nullable: nullable,
                     permissions: permissions,
                     deprecated: deprecated,
                     title: title,
                     description: description,
                     externalDocs: externalDocs,
                     allowedValues: allowedValues,
                     example: example)
    }

    /// Return the required version of this context
    public func requiredContext() -> JSONSchema.Context<Format> {
        return .init(format: format,
                     required: true,
                     nullable: nullable,
                     permissions: permissions,
                     deprecated: deprecated,
                     title: title,
                     description: description,
                     externalDocs: externalDocs,
                     allowedValues: allowedValues,
                     example: example)
    }

    /// Return the nullable version of this context
    public func nullableContext() -> JSONSchema.Context<Format> {
        return .init(format: format,
                     required: required,
                     nullable: true,
                     permissions: permissions,
                     deprecated: deprecated,
                     title: title,
                     description: description,
                     externalDocs: externalDocs,
                     allowedValues: allowedValues,
                     example: example)
    }

    /// Return this context with the given list of possible values
    public func with(allowedValues: [AnyCodable]) -> JSONSchema.Context<Format> {
        return .init(format: format,
                     required: required,
                     nullable: nullable,
                     permissions: permissions,
                     deprecated: deprecated,
                     title: title,
                     description: description,
                     externalDocs: externalDocs,
                     allowedValues: allowedValues,
                     example: example)
    }

    /// Return this context with the given example
    public func with<T: Encodable>(example: T, using encoder: JSONEncoder) -> JSONSchema.Context<Format> {
        return .init(format: format,
                     required: required,
                     nullable: nullable,
                     permissions: permissions,
                     deprecated: deprecated,
                     title: title,
                     description: description,
                     externalDocs: externalDocs,
                     allowedValues: allowedValues,
                     example: (codable: example, encoder: encoder))
    }
}

// MARK: - Specific Contexts

extension JSONSchema {
    public struct NumericContext: Equatable {
        public struct Bound: Equatable {
            public let value: Double
            public let exclusive: Bool
        }

        /// A numeric instance is valid only if division by this keyword's value results in an integer. Defaults to nil.
        public let multipleOf: Double?

        public let maximum: Bound?
        public let minimum: Bound?

        public init(multipleOf: Double? = nil,
                    maximum: (Double, exclusive: Bool)? = nil,
                    minimum: (Double, exclusive: Bool)? = nil) {
            self.multipleOf = multipleOf
            self.maximum = maximum.map { Bound(value: $0.0, exclusive: $0.exclusive) }
            self.minimum = minimum.map { Bound(value: $0.0, exclusive: $0.exclusive) }
        }
    }

    public struct IntegerContext: Equatable {
        public struct Bound: Equatable {
            public let value: Int
            public let exclusive: Bool
        }

        /// A numeric instance is valid only if division by this keyword's value results in an integer. Defaults to nil.
        public let multipleOf: Int?

        public let maximum: Bound?
        public let minimum: Bound?

        public init(multipleOf: Int? = nil,
                    maximum: (Int, exclusive: Bool)? = nil,
                    minimum: (Int, exclusive: Bool)? = nil) {
            self.multipleOf = multipleOf
            self.maximum = maximum.map { Bound(value: $0.0, exclusive: $0.exclusive) }
            self.minimum = minimum.map { Bound(value: $0.0, exclusive: $0.exclusive) }
        }
    }

    public struct StringContext: Equatable {
        public let maxLength: Int?
        public let minLength: Int

        /// Regular expression
        public let pattern: String?

        public init(maxLength: Int? = nil,
                    minLength: Int = 0,
                    pattern: String? = nil) {
            self.maxLength = maxLength
            self.minLength = minLength
            self.pattern = pattern
        }
    }

    public struct ArrayContext: Equatable {
        /// A JSON Type Node that describes
        /// the type of each element in the array.
        public let items: JSONSchema?

        /// Maximum number of items in array.
        public let maxItems: Int?

        /// Minimum number of items in array.
        /// Defaults to 0.
        public let minItems: Int

        /// Setting to true indicates all
        /// elements of the array are expected
        /// to be unique. Defaults to false.
        public let uniqueItems: Bool

        public init(items: JSONSchema? = nil,
                    maxItems: Int? = nil,
                    minItems: Int = 0,
                    uniqueItems: Bool = false) {
            self.items = items
            self.maxItems = maxItems
            self.minItems = minItems
            self.uniqueItems = uniqueItems
        }
    }

    public struct ObjectContext: Equatable {
        public let maxProperties: Int?
        let _minProperties: Int
        public let properties: [String: JSONSchema]
        public let additionalProperties: Either<Bool, JSONSchema>?

        // NOTE that an object's required properties
        // array is determined by looking at its properties'
        // required Bool.
        public var requiredProperties: [String] {
            return Array(properties.filter { (_, schemaObject) in
                schemaObject.required
            }.keys)
        }

        public var minProperties: Int {
            return max(_minProperties, requiredProperties.count)
        }

        public init(properties: [String: JSONSchema],
                    additionalProperties: Either<Bool, JSONSchema>? = nil,
                    maxProperties: Int? = nil,
                    minProperties: Int = 0) {
            self.properties = properties
            self.additionalProperties = additionalProperties
            self.maxProperties = maxProperties
            self._minProperties = minProperties
        }
    }
}

// MARK: - Codable

extension JSONSchema.Context {
    private enum CodingKeys: String, CodingKey {
        case type
        case format
        case title
        case description
        case externalDocs
        case allowedValues = "enum"
        case nullable
        case example
        case readOnly
        case writeOnly
        case deprecated
//        case constantValue = "const"
    }
}

extension JSONSchema.Context: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(format.jsonType, forKey: .type)

        if format != Format.unspecified {
            try container.encode(format, forKey: .format)
        }

        try allowedValues.encodeIfNotNil(to: &container, forKey: .allowedValues)

        try title.encodeIfNotNil(to: &container, forKey: .title)

        try description.encodeIfNotNil(to: &container, forKey: .description)

        try externalDocs.encodeIfNotNil(to: &container, forKey: .externalDocs)

        // nullable is false if omitted
        if nullable {
            try container.encode(nullable, forKey: .nullable)
        }

        switch permissions {
        case .readOnly:
            try container.encode(true, forKey: .readOnly)
        case .writeOnly:
            try container.encode(true, forKey: .writeOnly)
        case .readWrite:
            break
        }

        if deprecated {
            try container.encode(deprecated, forKey: .deprecated)
        }

        try example.encodeIfNotNil(to: &container, forKey: .example)
    }
}

extension JSONSchema.Context: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        format = try container.decodeIfPresent(Format.self, forKey: .format) ?? .unspecified

        // default to false at decoding site. It is the responsibility of
        // decoders farther upstream to mark this as required if needed
        // using `.requiredContext()`.
        required = false

        title = try container.decodeIfPresent(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)

        externalDocs = try container.decodeIfPresent(OpenAPI.ExternalDoc.self, forKey: .externalDocs)

        allowedValues = try container.decodeIfPresent([AnyCodable].self, forKey: .allowedValues)

        nullable = try container.decodeIfPresent(Bool.self, forKey: .nullable) ?? false

        let readOnly = try container.decodeIfPresent(Bool.self, forKey: .readOnly) ?? false
        let writeOnly = try container.decodeIfPresent(Bool.self, forKey: .writeOnly) ?? false
        switch (readOnly, writeOnly) {
        case (false, false):
            permissions = .readWrite
        case (false, true):
            permissions = .writeOnly
        case (true, false):
            permissions = .readOnly
        case (true, true):
            throw InconsistencyError(
                subjectName: "JSONSchema",
                details: "Either `readOnly` or `writeOnly` can be true but not both",
                codingPath: decoder.codingPath
            )
        }

        deprecated = try container.decodeIfPresent(Bool.self, forKey: .deprecated) ?? false

        if let decodedExample = try container.decodeIfPresent(AnyCodable.self, forKey: .example) {
            if let fragment = decodedExample.value as? String {
                example = fragment
            } else {
                example = try String(data: JSONEncoder().encode(decodedExample), encoding: .utf8)!
            }
        } else {
            example = nil
        }
    }
}

extension JSONSchema.NumericContext {
    private enum CodingKeys: String, CodingKey {
        case multipleOf
        case maximum
        case exclusiveMaximum
        case minimum
        case exclusiveMinimum
    }
}

extension JSONSchema.NumericContext: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try multipleOf.encodeIfNotNil(to: &container, forKey: .multipleOf)

        if let max = maximum {
            try container.encode(max.value, forKey: .maximum)
            if max.exclusive {
                try container.encode(true, forKey: .exclusiveMaximum)
            }
        }

        if let min =  minimum {
            try container.encode(min.value, forKey: .minimum)
            if min.exclusive {
                try container.encode(true, forKey: .exclusiveMinimum)
            }
        }
    }
}

extension JSONSchema.NumericContext: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        multipleOf = try container.decodeIfPresent(Double.self, forKey: .multipleOf)

        let exclusiveMaximum = try container.decodeIfPresent(Bool.self, forKey: .exclusiveMaximum) ?? false
        let exclusiveMinimum = try container.decodeIfPresent(Bool.self, forKey: .exclusiveMinimum) ?? false

        maximum = (try container.decodeIfPresent(Double.self, forKey: .maximum))
            .map { Bound(value: $0, exclusive: exclusiveMaximum) }
        minimum = (try container.decodeIfPresent(Double.self, forKey: .minimum))
            .map { Bound(value: $0, exclusive: exclusiveMinimum) }
    }
}

extension JSONSchema.IntegerContext {
    private enum CodingKeys: String, CodingKey {
        case multipleOf
        case maximum
        case exclusiveMaximum
        case minimum
        case exclusiveMinimum
    }
}

extension JSONSchema.IntegerContext: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try multipleOf.encodeIfNotNil(to: &container, forKey: .multipleOf)

        if let max = maximum {
            try container.encode(max.value, forKey: .maximum)
            if max.exclusive {
                try container.encode(true, forKey: .exclusiveMaximum)
            }
        }

        if let min =  minimum {
            try container.encode(min.value, forKey: .minimum)
            if min.exclusive {
                try container.encode(true, forKey: .exclusiveMinimum)
            }
        }
    }
}

extension JSONSchema.IntegerContext: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        multipleOf = try container.decodeIfPresent(Int.self, forKey: .multipleOf)

        let exclusiveMaximum = try container.decodeIfPresent(Bool.self, forKey: .exclusiveMaximum) ?? false
        let exclusiveMinimum = try container.decodeIfPresent(Bool.self, forKey: .exclusiveMinimum) ?? false

        maximum = (try container.decodeIfPresent(Int.self, forKey: .maximum))
            .map { Bound(value: $0, exclusive: exclusiveMaximum) }
        minimum = (try container.decodeIfPresent(Int.self, forKey: .minimum))
            .map { Bound(value: $0, exclusive: exclusiveMinimum) }
    }
}

extension JSONSchema.StringContext {
    private enum CodingKeys: String, CodingKey {
        case maxLength
        case minLength
        case pattern
    }
}

extension JSONSchema.StringContext: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try maxLength.encodeIfNotNil(to: &container, forKey: .maxLength)

        if minLength > 0 {
            try container.encode(minLength, forKey: .minLength)
        }

        try pattern.encodeIfNotNil(to: &container, forKey: .pattern)
    }
}

extension JSONSchema.StringContext: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        maxLength = try container.decodeIfPresent(Int.self, forKey: .maxLength)
        minLength = try container.decodeIfPresent(Int.self, forKey: .minLength) ?? 0
        pattern = try container.decodeIfPresent(String.self, forKey: .pattern)
    }
}

extension JSONSchema.ArrayContext {
    private enum CodingKeys: String, CodingKey {
        case items
        case maxItems
        case minItems
        case uniqueItems
    }
}

extension JSONSchema.ArrayContext: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try items.encodeIfNotNil(to: &container, forKey: .items)

        try maxItems.encodeIfNotNil(to: &container, forKey: .maxItems)

        if minItems > 0 {
            // omission is the same as 0
            try container.encode(minItems, forKey: .minItems)
        }

        if uniqueItems {
            // omission is the same as false
            try container.encode(uniqueItems, forKey: .uniqueItems)
        }
    }
}

extension JSONSchema.ArrayContext: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        items = try container.decodeIfPresent(JSONSchema.self, forKey: .items)
        maxItems = try container.decodeIfPresent(Int.self, forKey: .maxItems)
        minItems = try container.decodeIfPresent(Int.self, forKey: .minItems) ?? 0
        uniqueItems = try container.decodeIfPresent(Bool.self, forKey: .uniqueItems) ?? false
    }
}

extension JSONSchema.ObjectContext {
    private enum CodingKeys: String, CodingKey {
        case maxProperties
        case minProperties
        case properties
        case additionalProperties
        case required
    }
}

extension JSONSchema.ObjectContext: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try maxProperties.encodeIfNotNil(to: &container, forKey: .maxProperties)

        if properties.count > 0 {
            try container.encode(properties, forKey: .properties)
        }

        try additionalProperties.encodeIfNotNil(to: &container, forKey: .additionalProperties)

        if !requiredProperties.isEmpty {
            try container.encode(requiredProperties, forKey: .required)
        }

        if _minProperties > 0 {
            try container.encode(_minProperties, forKey: .minProperties)
        }
    }
}

extension JSONSchema.ObjectContext: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        maxProperties = try container.decodeIfPresent(Int.self, forKey: .maxProperties)
        _minProperties = try container.decodeIfPresent(Int.self, forKey: .minProperties) ?? 0
        additionalProperties = try container.decodeIfPresent(Either<Bool, JSONSchema>.self, forKey: .additionalProperties)

        let requiredArray = try container.decodeIfPresent([String].self, forKey: .required) ?? []

        var decodedProperties = try container.decodeIfPresent([String: JSONSchema].self, forKey: .properties) ?? [:]

        decodedProperties.forEach { (propertyName, property) in
            if requiredArray.contains(propertyName) {
                decodedProperties[propertyName] = property.requiredSchemaObject()
            }
        }

        properties = decodedProperties
    }
}
