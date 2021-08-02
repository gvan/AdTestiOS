//
//  AMJSON.swift
//  AdmixerSDK
//
//  Created by Admixer on 30.04.2021.
//  Copyright © 2021 Admixer. All rights reserved.
//

import Foundation

public enum AMJSON: Codable, Equatable {
    struct AMJSONDecodingError: Error {
        let message: String
    }
    
    case boolean(Bool)
    case number(Double)
    case string(String)
    case array([AMJSON?])
    case object([String: AMJSON?])
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let boolean = try? container.decode(Bool.self) {
            self = .boolean(boolean)
        } else if let number = try? container.decode(Double.self) {
            // todo: try decoding all number types in standard library somehow?
            self = .number(number)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([AMJSON?].self) {
            self = .array(array)
        } else if let dictionary = try? container.decode([String: AMJSON?].self) {
            self = .object(dictionary)
        } else {
            throw AMJSONDecodingError(message: "could not decode a valid AMJSON")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .boolean(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .array(let values):
            try container.encode(values)
        case .object(let valueDictionary):
            try container.encode(valueDictionary)
        }
    }
}

extension AMJSON: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self = .boolean(value)
    }
}

extension AMJSON: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = .number(Double(value))
    }
}

extension AMJSON: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self = .number(value)
    }
}

extension AMJSON: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension AMJSON: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: AMJSON?...) {
        self = .array(elements)
    }
}

extension AMJSON: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, AMJSON?)...) {
        self = .object(Dictionary.init(uniqueKeysWithValues: elements))
    }
}
