import Foundation

/// A field range representing the byte positions of a CSV field within raw data.
///
/// `CSVFieldRange` provides a lightweight representation of a CSV field's location
/// in the original data buffer, enabling lazy evaluation and zero-copy operations.
/// This is particularly useful for large CSV files where creating strings for
/// every field upfront would be memory-intensive.
///
/// ## Usage
///
/// ```swift
/// let parser = ByteCSVParser()
/// if let (rowBytes, _) = parser.parseRow(from: csvData) {
///     for fieldRange in rowBytes.fields {
///         if let fieldValue = fieldRange.extractString(from: csvData) {
///             print("Field: \(fieldValue)")
///         }
///     }
/// }
/// ```
///
/// ## See Also
/// - ``CSVRowBytes``
/// - ``ByteCSVParser``
public struct CSVFieldRange: Sendable {

  /// The starting byte position of the field in the source data
  public let start: Int

  /// The ending byte position (exclusive) of the field in the source data
  public let end: Int

  /// Whether this field was quoted in the original CSV
  public let isQuoted: Bool

  /**
   Extract the string value from the given data.
  
   This method converts the byte range to a string using the specified encoding,
   handling CSV-specific concerns like quote unescaping for quoted fields.
  
   - Parameters:
     - data: The source data buffer containing the CSV content
     - encoding: The string encoding to use (defaults to UTF-8)
   - Returns: The field value as a string, or `nil` if extraction fails
   */
  public func extractString(from data: Data, encoding: String.Encoding = .utf8) -> String? {
    guard start <= end, start >= 0, end <= data.count else { return nil }

    // Handle empty fields
    if start == end {
      return ""
    }

    // Adjust for Data slices that may have non-zero startIndex
    let adjustedStart = data.startIndex + start
    let adjustedEnd = data.startIndex + end
    let fieldData = data[adjustedStart..<adjustedEnd]
    guard let rawString = String(data: fieldData, encoding: encoding) else {
      return nil
    }

    // For quoted fields, we need to handle escaped quotes
    if isQuoted {
      // The field data already excludes the outer quotes (handled in parser)
      // Standard CSV: "" becomes "
      return rawString.replacingOccurrences(of: "\"\"", with: "\"")
    }

    return rawString
  }
}

/// A row of CSV field ranges for lazy evaluation.
///
/// `CSVRowBytes` represents a parsed CSV row as a collection of field ranges
/// rather than pre-computed strings. This enables lazy evaluation where field
/// values are only converted to strings when accessed, reducing memory usage
/// for large CSV files.
///
/// ## Usage
///
/// ```swift
/// let parser = ByteCSVParser()
/// if let (rowBytes, _) = parser.parseRow(from: csvData) {
///     // Access individual fields
///     if let name = rowBytes.field(at: 0) {
///         print("Name: \(name)")
///     }
///
///     // Get all fields as strings
///     let allFields = rowBytes.stringFields
///     print("Row: \(allFields)")
/// }
/// ```
///
/// ## Performance Benefits
///
/// - **Lazy evaluation**: Field strings are created only when accessed
/// - **Zero-copy**: Field ranges reference original data without copying
/// - **Memory efficient**: Ideal for processing large CSV files row by row
///
/// ## See Also
///
/// - ``CSVFieldRange``
/// - ``ByteCSVParser``
public struct CSVRowBytes: Sendable {

  /// The original data buffer containing the CSV row
  public let data: Data

  /// Array of field ranges within the data buffer
  public let fields: [CSVFieldRange]

  /// The string encoding used for this row
  public let encoding: String.Encoding

  /**
   Get all fields as an array of strings.
  
   This computed property converts all field ranges to strings in one
   operation. For better performance when accessing only some fields, use
   ``field(at:)`` instead.
  
   - Returns: Array containing all field values as strings
   */
  public var stringFields: [String] {
    fields.compactMap { $0.extractString(from: data, encoding: encoding) }
  }

  /**
   Creates a new CSV row bytes instance.
  
   - Parameters:
     - data: The data buffer containing the CSV content
     - fields: Array of field ranges within the data
     - encoding: String encoding for the data (defaults to UTF-8)
   */
  public init(data: Data, fields: [CSVFieldRange], encoding: String.Encoding = .utf8) {
    self.data = data
    self.fields = fields
    self.encoding = encoding
  }

  /**
   Get field value at the specified index as a string.
  
   - Parameter index: The zero-based index of the field to retrieve
   - Returns: The field value as a string, or `nil` if the index is out of bounds
   */
  public func field(at index: Int) -> String? {
    guard index < fields.count else { return nil }
    return fields[index].extractString(from: data, encoding: encoding)
  }
}

/// High-performance byte-level CSV parser.
///
/// `ByteCSVParser` processes CSV data at the byte level, avoiding string operations
/// until field values are actually needed. This approach provides significant
/// performance and memory benefits, especially for large CSV files.
///
/// ## Features
///
/// - **Zero-copy parsing**: Returns field ranges instead of creating strings immediately
/// - **Memory efficient**: Processes data without loading entire rows into memory as strings
/// - **High performance**: Direct byte-level operations avoid UTF-8 string conversion overhead
/// - **Flexible**: Supports custom delimiters, quotes, and escape characters
///
/// ## Usage
///
/// ```swift
/// let parser = ByteCSVParser(delimiter: ",", quote: "\"", escape: "\"")
/// let csvData = "Alice,30,\"New York\"\nBob,25,\"Los Angeles\"".data(using: .utf8)!
///
/// if let (rowBytes, consumed) = parser.parseRow(from: csvData) {
///     print("Fields: \(rowBytes.stringFields)")
///
///     // Process remaining data
///     let remainingData = csvData.dropFirst(consumed)
///     // ...
/// }
/// ```
///
/// ## Performance Characteristics
///
/// - **O(n)** time complexity where n is the data size
/// - **O(1)** memory overhead per field (just stores byte ranges)
/// - No intermediate string allocations during parsing
///
/// ## See Also
/// - ``CSVRowBytes``
/// - ``CSVFieldRange``
public struct ByteCSVParser: Sendable {
  private static let lf: UInt8 = 0x0A  // \n
  private static let cr: UInt8 = 0x0D  // \r

  /// The byte value used as field delimiter
  public let delimiter: UInt8

  /// The byte value used for quoting fields
  public let quote: UInt8

  /// The byte value used for escaping special characters
  public let escape: UInt8

  /// The string encoding to use when converting bytes to strings
  public let encoding: String.Encoding

  // Pre-computed sets for fast lookup
  private let specialBytes: Set<UInt8>
  private let lineEndingBytes: Set<UInt8> = [Self.lf, Self.cr]

  public init(
    delimiter: Character = ",",
    quote: Character = "\"",
    escape: Character = "\"",
    encoding: String.Encoding = .utf8
  ) {
    // Convert characters to UTF-8 bytes
    self.delimiter = delimiter.utf8.first!
    self.quote = quote.utf8.first!
    self.escape = escape.utf8.first!
    self.encoding = encoding

    // Pre-compute special bytes for fast checking
    self.specialBytes = [self.delimiter, self.quote, Self.lf, Self.cr]
  }

  /**
   Parse a complete row from data, returning field ranges
   Returns nil if no complete row is found
  
   - Parameters:
     - data: The data to parse
     - isEndOfFile: If true, treats end of data as end of row (for last row without newline)
   */
  public func parseRow(from data: Data, isEndOfFile: Bool = true) -> (
    row: CSVRowBytes, consumedBytes: Int
  )? {
    var fields: [CSVFieldRange] = []
    fields.reserveCapacity(16)  // Pre-allocate for typical row size

    var pos = 0
    var fieldStart = 0
    var inQuotes = false
    var afterQuote = false
    let dataCount = data.count

    // Use withUnsafeBytes for direct memory access
    return data.withUnsafeBytes { bytes in
      let ptr = bytes.bindMemory(to: UInt8.self)

      while pos < dataCount {
        let byte = ptr[pos]

        if afterQuote {
          // After closing quote, expecting delimiter or line ending
          if byte == delimiter {
            // End of quoted field
            fields.append(
              CSVFieldRange(
                start: fieldStart,
                end: pos - 1,  // Exclude the closing quote
                isQuoted: true
              )
            )
            pos += 1
            fieldStart = pos
            afterQuote = false
            continue
          }
          if byte == Self.lf || byte == Self.cr {
            // End of row after quoted field
            fields.append(
              CSVFieldRange(
                start: fieldStart,
                end: pos - 1,  // Exclude the closing quote
                isQuoted: true
              )
            )

            // Handle line endings
            pos += 1
            if byte == Self.cr && pos < dataCount && ptr[pos] == Self.lf {
              pos += 1  // Skip LF in CRLF
            }

            return (CSVRowBytes(data: data, fields: fields, encoding: encoding), pos)
          }
          if byte == quote {
            // Double quote - continue in quoted mode
            afterQuote = false
            inQuotes = true
            pos += 1
            continue
          }
          // Invalid - treat as part of unquoted field
          afterQuote = false
          inQuotes = false
        }

        if inQuotes {
          // Inside quoted field
          if byte == escape && pos + 1 < dataCount && ptr[pos + 1] == quote {
            // Escaped quote - skip escape but keep the quote
            pos += 2
            continue
          }
          if byte == quote {
            // End of quoted field
            inQuotes = false
            afterQuote = true
            pos += 1
            continue
          }
          // Regular character in quoted field
          pos += 1
          continue
        }
        // Not in quotes
        if byte == quote && pos == fieldStart {
          // Start of quoted field
          inQuotes = true
          fieldStart = pos + 1  // Skip opening quote
          pos += 1
          continue
        }
        if byte == delimiter {
          // End of unquoted field
          fields.append(
            CSVFieldRange(
              start: fieldStart,
              end: pos,
              isQuoted: false
            )
          )
          pos += 1
          fieldStart = pos
          continue
        }
        if byte == Self.lf || byte == Self.cr {
          // End of row
          fields.append(
            CSVFieldRange(
              start: fieldStart,
              end: pos,
              isQuoted: false
            )
          )

          // Handle line endings
          pos += 1
          if byte == Self.cr && pos < dataCount && ptr[pos] == Self.lf {
            pos += 1  // Skip LF in CRLF
          }

          return (CSVRowBytes(data: data, fields: fields, encoding: encoding), pos)
        }
        // Regular character
        pos += 1
        continue
      }

      // Handle end of data
      // Only return a row if:
      // 1. We're at the actual end of file (isEndOfFile == true), OR
      // 2. We have an empty data (no fields started)
      // Otherwise, this is an incomplete row and we need more data
      if isEndOfFile && !inQuotes && (fieldStart < dataCount || !fields.isEmpty) {
        // Add final field
        let end = afterQuote ? pos - 1 : pos
        fields.append(
          CSVFieldRange(
            start: fieldStart,
            end: end,
            isQuoted: afterQuote
          )
        )
        return (CSVRowBytes(data: data, fields: fields, encoding: encoding), pos)
      }

      // Incomplete row or end of buffer - return nil so caller knows to get more data
      return nil
    }
  }

  func parseSimpleRow(from data: Data) -> (row: CSVRowBytes, consumedBytes: Int)? {
    var fields: [CSVFieldRange] = []
    fields.reserveCapacity(16)

    var fieldStart = 0
    var pos = 0
    let dataCount = data.count

    return data.withUnsafeBytes { bytes in
      let ptr = bytes.bindMemory(to: UInt8.self)

      while pos < dataCount {
        let byte = ptr[pos]

        // Bail out if we see a quote
        if byte == quote {
          return nil
        }

        if byte == delimiter {
          fields.append(
            CSVFieldRange(
              start: fieldStart,
              end: pos,
              isQuoted: false
            )
          )
          pos += 1
          fieldStart = pos
        } else if byte == Self.lf || byte == Self.cr {
          // End of row
          fields.append(
            CSVFieldRange(
              start: fieldStart,
              end: pos,
              isQuoted: false
            )
          )

          pos += 1
          if byte == Self.cr && pos < dataCount && ptr[pos] == Self.lf {
            pos += 1
          }

          return (CSVRowBytes(data: data, fields: fields, encoding: encoding), pos)
        } else {
          pos += 1
        }
      }

      // End of data
      if fieldStart < dataCount || !fields.isEmpty {
        fields.append(
          CSVFieldRange(
            start: fieldStart,
            end: pos,
            isQuoted: false
          )
        )
        return (CSVRowBytes(data: data, fields: fields, encoding: encoding), pos)
      }

      return nil
    }
  }

  func findRowBoundary(in data: Data, startingAt offset: Int = 0) -> Int? {
    guard offset < data.count else { return nil }

    return data.withUnsafeBytes { bytes in
      let ptr = bytes.bindMemory(to: UInt8.self)
      var pos = offset
      var inQuotes = false

      // Scan forward to find a line ending outside of quotes
      while pos < data.count {
        let byte = ptr[pos]

        if byte == quote {
          // Check if it's an escaped quote
          if inQuotes && pos + 1 < data.count && ptr[pos + 1] == quote {
            pos += 2  // Skip escaped quote
            continue
          }
          inQuotes.toggle()
        } else if !inQuotes && (byte == Self.lf || byte == Self.cr) {
          // Found line ending outside quotes
          pos += 1
          if byte == Self.cr && pos < data.count && ptr[pos] == Self.lf {
            pos += 1  // Skip LF in CRLF
          }
          return pos
        }

        pos += 1
      }

      // If we're not in quotes at the end, the entire data is valid
      return inQuotes ? nil : data.count
    }
  }

  func extractFields(from rowBytes: CSVRowBytes) -> [String] {
    rowBytes.stringFields
  }

  func parseRowToStrings(from data: Data) -> (fields: [String], consumedBytes: Int)? {
    guard let (rowBytes, consumed) = parseRow(from: data) else {
      return nil
    }
    return (rowBytes.stringFields, consumed)
  }
}
