import Foundation

/// An intermediate representation for TOON values during encoding and decoding.
public enum Value: Equatable, Sendable {
    case null
    case bool(Bool)
    case int(Int64)
    case double(Double)
    case string(String)
    case date(Date)
    case url(URL)
    case data(Data)
    case array([Value])
    case object([String: Value], keyOrder: [String])

    // MARK: - Type Checks

    var isNull: Bool {
        if case .null = self { return true }
        return false
    }

    var isPrimitive: Bool {
        switch self {
        case .null, .bool, .int, .double, .string, .date, .url, .data:
            return true
        case .array, .object:
            return false
        }
    }

    var isArray: Bool {
        if case .array = self { return true }
        return false
    }

    var isObject: Bool {
        if case .object = self { return true }
        return false
    }

    // MARK: - Value Accessors

    var boolValue: Bool? {
        if case let .bool(v) = self { return v }
        return nil
    }

    var intValue: Int64? {
        if case let .int(v) = self { return v }
        return nil
    }

    var doubleValue: Double? {
        if case let .double(v) = self { return v }
        // Also allow int to double conversion
        if case let .int(v) = self { return Double(v) }
        return nil
    }

    var stringValue: String? {
        if case let .string(v) = self { return v }
        return nil
    }

    var arrayValue: [Value]? {
        if case let .array(v) = self { return v }
        return nil
    }

    var objectValue: (values: [String: Value], keyOrder: [String])? {
        if case let .object(values, keyOrder) = self { return (values, keyOrder) }
        return nil
    }

    var typeName: String {
        switch self {
        case .null: return "null"
        case .bool: return "bool"
        case .int: return "int"
        case .double: return "double"
        case .string: return "string"
        case .date: return "date"
        case .url: return "url"
        case .data: return "data"
        case .array: return "array"
        case .object: return "object"
        }
    }

    // MARK: - Array Type Checks

    var isArrayOfPrimitives: Bool {
        guard let array = arrayValue else { return false }
        return array.allSatisfy { $0.isPrimitive }
    }

    var isArrayOfArrays: Bool {
        guard let array = arrayValue else { return false }
        return array.allSatisfy { $0.isArray }
    }

    var isArrayOfObjects: Bool {
        guard let array = arrayValue else { return false }
        return array.allSatisfy { $0.isObject }
    }

}

// MARK: - Codable

extension Value: Codable {
    public init(from decoder: Decoder) throws {
        // Try object first (keyed container)
        if let container = try? decoder.container(keyedBy: DynamicCodingKey.self),
           !container.allKeys.isEmpty {
            var values: [String: Value] = [:]
            var keyOrder: [String] = []
            for key in container.allKeys {
                values[key.stringValue] = try container.decode(Value.self, forKey: key)
                keyOrder.append(key.stringValue)
            }
            self = .object(values, keyOrder: keyOrder)
            return
        }

        // Try array (unkeyed container)
        if var container = try? decoder.unkeyedContainer() {
            var array: [Value] = []
            while !container.isAtEnd {
                array.append(try container.decode(Value.self))
            }
            self = .array(array)
            return
        }

        // Primitives (single value container)
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
            return
        }

        // Int64 before Bool (0/1 can decode as Bool)
        if let v = try? container.decode(Int64.self) { self = .int(v); return }
        if let v = try? container.decode(Bool.self) { self = .bool(v); return }
        if let v = try? container.decode(Double.self) { self = .double(v); return }
        if let v = try? container.decode(String.self) { self = .string(v); return }

        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unable to decode Value")
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .null:
            var container = encoder.singleValueContainer()
            try container.encodeNil()
        case let .bool(v):
            var container = encoder.singleValueContainer()
            try container.encode(v)
        case let .int(v):
            var container = encoder.singleValueContainer()
            try container.encode(v)
        case let .double(v):
            var container = encoder.singleValueContainer()
            try container.encode(v)
        case let .string(v):
            var container = encoder.singleValueContainer()
            try container.encode(v)
        case let .date(v):
            var container = encoder.singleValueContainer()
            try container.encode(v)
        case let .url(v):
            var container = encoder.singleValueContainer()
            try container.encode(v)
        case let .data(v):
            var container = encoder.singleValueContainer()
            try container.encode(v)
        case let .array(v):
            var container = encoder.unkeyedContainer()
            for item in v {
                try container.encode(item)
            }
        case let .object(values, keyOrder):
            var container = encoder.container(keyedBy: DynamicCodingKey.self)
            for key in keyOrder {
                if let value = values[key] {
                    try container.encode(value, forKey: DynamicCodingKey(stringValue: key))
                }
            }
        }
    }
}

private struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }

    init(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        self.stringValue = String(intValue)
    }
}

// MARK: - Coding Key

struct IndexedCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init(stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init(intValue: Int) {
        stringValue = String(intValue)
        self.intValue = intValue
    }
}
