import Foundation

// swiftlint:disable missing_docs

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
    guard let data = Data(base64Encoded: csvString.trimmingCharacters(in: .whitespacesAndNewlines))
    else {
      return nil
    }
    self = data
  }
}

// MARK: - RawRepresentable

// Provide default implementations for RawRepresentable types
// Note: Types must still explicitly declare conformance to CSVCodable/CSVEncodable/CSVDecodable

// String raw values
extension CSVEncodable where Self: RawRepresentable, RawValue == String {
  public var csvString: String {
    rawValue
  }
}

extension CSVDecodable where Self: RawRepresentable, RawValue == String {
  public init?(csvString: String) {
    // Don't trim - let the application handle whitespace
    self.init(rawValue: csvString)
  }
}

// Int raw values
extension CSVEncodable where Self: RawRepresentable, RawValue == Int {
  public var csvString: String { String(rawValue) }
}
extension CSVDecodable where Self: RawRepresentable, RawValue == Int {
  public init?(csvString: String) {
    guard let value = Int(csvString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
      return nil
    }
    self.init(rawValue: value)
  }
}

// Int8 raw values
extension CSVEncodable where Self: RawRepresentable, RawValue == Int8 {
  public var csvString: String { String(rawValue) }
}
extension CSVDecodable where Self: RawRepresentable, RawValue == Int8 {
  public init?(csvString: String) {
    guard let value = Int8(csvString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
      return nil
    }
    self.init(rawValue: value)
  }
}

// Int16 raw values
extension CSVEncodable where Self: RawRepresentable, RawValue == Int16 {
  public var csvString: String { String(rawValue) }
}
extension CSVDecodable where Self: RawRepresentable, RawValue == Int16 {
  public init?(csvString: String) {
    guard let value = Int16(csvString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
      return nil
    }
    self.init(rawValue: value)
  }
}

// Int32 raw values
extension CSVEncodable where Self: RawRepresentable, RawValue == Int32 {
  public var csvString: String { String(rawValue) }
}
extension CSVDecodable where Self: RawRepresentable, RawValue == Int32 {
  public init?(csvString: String) {
    guard let value = Int32(csvString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
      return nil
    }
    self.init(rawValue: value)
  }
}

// Int64 raw values
extension CSVEncodable where Self: RawRepresentable, RawValue == Int64 {
  public var csvString: String { String(rawValue) }
}
extension CSVDecodable where Self: RawRepresentable, RawValue == Int64 {
  public init?(csvString: String) {
    guard let value = Int64(csvString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
      return nil
    }
    self.init(rawValue: value)
  }
}

// UInt raw values
extension CSVEncodable where Self: RawRepresentable, RawValue == UInt {
  public var csvString: String { String(rawValue) }
}
extension CSVDecodable where Self: RawRepresentable, RawValue == UInt {
  public init?(csvString: String) {
    guard let value = UInt(csvString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
      return nil
    }
    self.init(rawValue: value)
  }
}

// UInt8 raw values
extension CSVEncodable where Self: RawRepresentable, RawValue == UInt8 {
  public var csvString: String { String(rawValue) }
}
extension CSVDecodable where Self: RawRepresentable, RawValue == UInt8 {
  public init?(csvString: String) {
    guard let value = UInt8(csvString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
      return nil
    }
    self.init(rawValue: value)
  }
}

// UInt16 raw values
extension CSVEncodable where Self: RawRepresentable, RawValue == UInt16 {
  public var csvString: String { String(rawValue) }
}
extension CSVDecodable where Self: RawRepresentable, RawValue == UInt16 {
  public init?(csvString: String) {
    guard let value = UInt16(csvString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
      return nil
    }
    self.init(rawValue: value)
  }
}

// UInt32 raw values
extension CSVEncodable where Self: RawRepresentable, RawValue == UInt32 {
  public var csvString: String { String(rawValue) }
}
extension CSVDecodable where Self: RawRepresentable, RawValue == UInt32 {
  public init?(csvString: String) {
    guard let value = UInt32(csvString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
      return nil
    }
    self.init(rawValue: value)
  }
}

// UInt64 raw values
extension CSVEncodable where Self: RawRepresentable, RawValue == UInt64 {
  public var csvString: String { String(rawValue) }
}
extension CSVDecodable where Self: RawRepresentable, RawValue == UInt64 {
  public init?(csvString: String) {
    guard let value = UInt64(csvString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
      return nil
    }
    self.init(rawValue: value)
  }
}

// Character raw values
extension CSVEncodable where Self: RawRepresentable, RawValue == Character {
  public var csvString: String {
    String(rawValue)
  }
}

extension CSVDecodable where Self: RawRepresentable, RawValue == Character {
  public init?(csvString: String) {
    // Take first character after trimming
    let trimmed = csvString.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.count == 1,
      let firstChar = trimmed.first
    else { return nil }
    self.init(rawValue: firstChar)
  }
}

// MARK: - Optional

extension Optional: CSVCodable where Wrapped: CSVCodable {
  public var csvString: String {
    switch self {
      case .none:
        ""
      case .some(let value):
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

// swiftlint:enable missing_docs
