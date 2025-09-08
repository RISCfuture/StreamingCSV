import Foundation

// MARK: - String

extension String: CSVCodable {
    public var csvString: String { self }

    public init?(csvString: String) {
        // Just trim whitespace, don't return nil for empty strings
        // as that would break required fields
        self = csvString.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Integer Types

extension Int: CSVCodable {
    public var csvString: String { String(self) }

    public init?(csvString: String) {
        guard let value = Int(csvString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
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
        let trimmed = csvString.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch trimmed {
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
        guard let data = Data(base64Encoded: csvString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }
        self = data
    }
}

// MARK: - Optional

extension Optional: CSVEncodable where Wrapped: CSVEncodable {
    public var csvString: String {
        switch self {
        case .none:
            ""
        case let .some(value):
            value.csvString
        }
    }
}

extension Optional: CSVDecodable where Wrapped: CSVDecodable {
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
