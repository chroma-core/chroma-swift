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
