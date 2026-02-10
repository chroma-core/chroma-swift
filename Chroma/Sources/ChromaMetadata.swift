// Copyright 2026 Chroma
// Licensed under the Apache License, Version 2.0

import Foundation

public enum ChromaMetadataValue: Hashable, Sendable {
    case bool(Bool)
    case int(Int64)
    case float(Double)
    case string(String)
}

extension ChromaMetadataValue: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .bool(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .float(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        }
    }
}

extension ChromaMetadataValue: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
            return
        }
        if let value = try? container.decode(Int64.self) {
            self = .int(value)
            return
        }
        if let value = try? container.decode(Double.self) {
            self = .float(value)
            return
        }
        if let value = try? container.decode(String.self) {
            self = .string(value)
            return
        }
        throw DecodingError.typeMismatch(
            ChromaMetadataValue.self,
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Unsupported metadata value type."
            )
        )
    }
}

extension ChromaMetadataValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}

extension ChromaMetadataValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int64) {
        self = .int(value)
    }
}

extension ChromaMetadataValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self = .float(value)
    }
}

extension ChromaMetadataValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

public typealias ChromaMetadata = [String: ChromaMetadataValue]

public enum ChromaMetadataError: Error, LocalizedError {
    case countMismatch(expected: Int, actual: Int)
    case encodingFailed

    public var errorDescription: String? {
        switch self {
        case let .countMismatch(expected, actual):
            return "Metadata count (\(actual)) does not match ids count (\(expected))."
        case .encodingFailed:
            return "Failed to encode metadata as JSON."
        }
    }
}

public extension AdvancedGetResult {
    /// Decode metadata JSON strings into ChromaMetadata values.
    func decodedMetadatas() -> [ChromaMetadata?] {
        guard let metadatas else {
            return Array(repeating: nil, count: ids.count)
        }

        let decoded: [ChromaMetadata?] = metadatas.map { json in
            guard let json else { return nil as ChromaMetadata? }
            guard let data = json.data(using: .utf8) else { return nil as ChromaMetadata? }
            return try? JSONDecoder().decode(ChromaMetadata.self, from: data)
        }

        if decoded.count < ids.count {
            return decoded + Array(repeating: nil, count: ids.count - decoded.count)
        }
        if decoded.count > ids.count {
            return Array(decoded.prefix(ids.count))
        }
        return decoded
    }
}

private extension Dictionary where Key == String, Value == ChromaMetadataValue {
    func chromaJSON() throws -> String {
        let encoder = JSONEncoder()
        let data = try encoder.encode(self)
        guard let json = String(data: data, encoding: .utf8) else {
            throw ChromaMetadataError.encodingFailed
        }
        return json
    }
}

public func addDocuments(
    collectionName: String,
    ids: [String],
    embeddings: [[Float]],
    documents: [String]
) throws -> UInt32 {
    return try addDocuments(
        collectionName: collectionName,
        ids: ids,
        embeddings: embeddings,
        documents: documents,
        metadatas: nil as [String?]?
    )
}

public func addDocuments(
    collectionName: String,
    ids: [String],
    embeddings: [[Float]],
    documents: [String],
    metadatas: [ChromaMetadata?]
) throws -> UInt32 {
    if metadatas.count != ids.count {
        throw ChromaMetadataError.countMismatch(expected: ids.count, actual: metadatas.count)
    }

    let metadatasJSON = try metadatas.map { metadata in
        try metadata?.chromaJSON()
    }

    return try addDocuments(
        collectionName: collectionName,
        ids: ids,
        embeddings: embeddings,
        documents: documents,
        metadatas: metadatasJSON
    )
}
