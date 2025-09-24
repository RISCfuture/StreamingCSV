import Foundation

/// A type that represents a complete CSV row with both reading and writing capabilities.
///
/// `CSVRow` combines ``CSVDecodableRow`` and ``CSVEncodableRow`` protocols for types
/// that need bidirectional CSV conversion. Types conforming to `CSVRow` can be used
/// with both ``StreamingCSVReader/readRow()`` and ``StreamingCSVWriter/writeRow(_:)``.
///
/// ## Conforming to CSVRow
///
/// You can manually conform to `CSVRow` or use the ``CSVRowBuilder()`` macro for
/// automatic implementation:
///
/// ```swift
/// @CSVRowBuilder
/// struct Person {
///     @Field var name: String
///     @Field var age: Int
///     @Field var city: String
/// }
/// ```
///
/// ## Choosing the Right Protocol
///
/// - Use ``CSVRow`` when you need both reading and writing capabilities
/// - Use ``CSVDecodableRow`` for read-only CSV parsing (requires only `CSVDecodable` types)
/// - Use ``CSVEncodableRow`` for write-only CSV generation (requires only `CSVEncodable` types)
public protocol CSVRow: CSVDecodableRow, CSVEncodableRow {}
