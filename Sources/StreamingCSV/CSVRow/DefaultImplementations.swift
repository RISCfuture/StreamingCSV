import Foundation

// MARK: - String

extension String: CSVCodable {
    public var csvString: String { self }

    public init?(csvString: String) {
        // Don't trim - let the application decide how to handle whitespace
        self = csvString
    }
}

// MARK: - Integer Types

extension Int: CSVCodable {
    public var csvString: String { String(self) }

    public init?(csvString: String) {
        // Trim for numeric parsing since Swift's Int() doesn't handle whitespace
        guard let value = Int(csvString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }
        self = value
    }
}

extension Int8: CSVCodable {
    public var csvString: String { String(self) }

    public init?(csvString: String) {
        guard let value = Int8(csvString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }
        self = value
    }
}

extension Int16: CSVCodable {
    public var csvString: String { String(self) }

    public init?(csvString: String) {
        guard let value = Int16(csvString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }
        self = value
    }
}

extension Int32: CSVCodable {
    public var csvString: String { String(self) }

    public init?(csvString: String) {
        guard let value = Int32(csvString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }
        self = value
    }
}

extension Int64: CSVCodable {
    public var csvString: String { String(self) }

    public init?(csvString: String) {
        guard let value = Int64(csvString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }
        self = value
    }
}

extension UInt: CSVCodable {
    public var csvString: String { String(self) }

    public init?(csvString: String) {
        guard let value = UInt(csvString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }
        self = value
    }
}

extension UInt8: CSVCodable {
    public var csvString: String { String(self) }

    public init?(csvString: String) {
        guard let value = UInt8(csvString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }
        self = value
    }
}

extension UInt16: CSVCodable {
    public var csvString: String { String(self) }

    public init?(csvString: String) {
        guard let value = UInt16(csvString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }
        self = value
    }
}

extension UInt32: CSVCodable {
    public var csvString: String { String(self) }

    public init?(csvString: String) {
        guard let value = UInt32(csvString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }
        self = value
    }
}

extension UInt64: CSVCodable {
    public var csvString: String { String(self) }

    public init?(csvString: String) {
        guard let value = UInt64(csvString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }
        self = value
    }
}

// MARK: - Floating Point Types

extension Double: CSVCodable {
    public var csvString: String { String(self) }

    public init?(csvString: String) {
        guard let value = Double(csvString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }
        self = value
    }
}

extension Float: CSVCodable {
    public var csvString: String { String(self) }

    public init?(csvString: String) {
        guard let value = Float(csvString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }
        self = value
    }
}

// MARK: - Boolean

extension Bool: CSVCodable {
    public var csvString: String { self ? "true" : "false" }

    public init?(csvString: String) {
        // Trim and lowercase for boolean parsing
        switch csvString.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "true", "yes", "1", "y", "t":
            self = true
        case "false", "no", "0", "n", "f":
            self = false
        default:
            return nil
        }
    }
}

// MARK: - Data

extension Data: CSVCodable {
    public var csvString: String {
        self.base64EncodedString()
    }

    public init?(csvString: String) {
        // Trim for base64 parsing
        guard let data = Data(base64Encoded: csvString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }
        self = data
    }
}

// MARK: - Optional

extension Optional: CSVCodable where Wrapped: CSVCodable {
    public var csvString: String {
        switch self {
        case .none:
            ""
        case let .some(value):
            value.csvString
        }
    }

    public init?(csvString: String) {
        if csvString.isEmpty {
            self = .none
        } else if let value = Wrapped(csvString: csvString) {
            self = .some(value)
        } else {
            return nil
        }
    }
}
