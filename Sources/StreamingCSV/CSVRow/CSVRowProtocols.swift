import Foundation

/// A type that can be decoded from a CSV row.
///
/// Types conforming to `CSVDecodableRow` can be initialized from an array of CSV field strings.
/// This protocol is useful for types that only need to read CSV data, not write it.
///
/// ## Conforming to CSVDecodableRow
///
/// You can manually conform to `CSVDecodableRow` or use the ``CSVRowDecoderBuilder()`` macro:
///
/// ```swift
/// @CSVRowDecoderBuilder
/// struct Person {
///     @Field var name: String
///     @Field var age: Int
///     @Field var city: String
/// }
/// ```
public protocol CSVDecodableRow {
  /**
   Creates a new instance from an array of CSV field strings.
  
   Implementations should validate the input and return `nil` if the fields
   cannot be parsed into a valid instance.
  
   - Parameter fields: An array of string values representing the CSV fields.
   - Returns: A new instance if parsing succeeds, or `nil` if the fields are invalid.
   */
  init?(from fields: [String])
}

/// A type that can be encoded to a CSV row.
///
/// Types conforming to `CSVEncodableRow` can be converted to an array of CSV field strings.
/// This protocol is useful for types that only need to write CSV data, not read it.
///
/// ## Conforming to CSVEncodableRow
///
/// You can manually conform to `CSVEncodableRow` or use the ``CSVRowEncoderBuilder()`` macro:
///
/// ```swift
/// @CSVRowEncoderBuilder
/// struct Report {
///     @Field var timestamp: Date
///     @Field var status: String
///     @Field var value: Double
/// }
/// ```
public protocol CSVEncodableRow {
  /**
   Converts this instance to an array of CSV field strings.
  
   The returned array should contain string representations of all fields
   in the correct order for CSV output.
  
   - Returns: An array of string values representing the CSV fields.
   */
  func toCSVRow() -> [String]
}
