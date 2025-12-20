import Foundation

/// An asynchronous sequence that transforms a stream of Data chunks into typed CSV rows.
///
/// `TypedCSVRowStream` wraps a ``CSVRowStream`` and converts each parsed row into
/// a strongly-typed value conforming to ``CSVDecodableRow``. Rows that fail to parse
/// into the target type are skipped.
///
/// ## Example
///
/// ```swift
/// @CSVRowBuilder
/// struct Person {
///     @Field var name: String
///     @Field var age: Int
/// }
///
/// let dataStream: AsyncThrowingStream<Data, Error> = ...
/// let rowStream = TypedCSVRowStream<Person, _>(source: dataStream)
///
/// for try await person in rowStream {
///     print("\(person.name) is \(person.age) years old")
/// }
/// ```
///
/// ## Skipping Headers
///
/// Use the `dropFirst()` method to skip header rows:
///
/// ```swift
/// for try await person in rowStream.dropFirst() {
///     // Process data rows only
/// }
/// ```
///
/// ## See Also
/// - ``CSVRowStream``
/// - ``CSVDecodableRow``
public struct TypedCSVRowStream<T: CSVDecodableRow, Source: AsyncSequence & Sendable>:
  AsyncSequence, Sendable
where Source.Element == Data, T: Sendable {
  public typealias Element = T

  private let rowStream: CSVRowStream<Source>

  /// Creates a new typed CSV row stream from an async sequence of Data chunks.
  ///
  /// - Parameters:
  ///   - source: The async sequence of Data chunks to parse.
  ///   - delimiter: The character used to separate fields. Defaults to comma (`,`).
  ///   - quote: The character used to quote fields. Defaults to double quote (`"`).
  ///   - escape: The character used to escape quotes. Defaults to double quote (`"`).
  ///   - encoding: The string encoding to use. Defaults to UTF-8.
  ///   - bufferCapacity: Initial buffer capacity in bytes. Defaults to 65536 (64KB).
  public init(
    source: Source,
    delimiter: Character = ",",
    quote: Character = "\"",
    escape: Character = "\"",
    encoding: String.Encoding = .utf8,
    bufferCapacity: Int = 65536
  ) {
    self.rowStream = CSVRowStream(
      source: source,
      delimiter: delimiter,
      quote: quote,
      escape: escape,
      encoding: encoding,
      bufferCapacity: bufferCapacity
    )
  }

  /// Creates a new typed CSV row stream from an existing CSVRowStream.
  ///
  /// - Parameter rowStream: The underlying row stream to wrap.
  public init(wrapping rowStream: CSVRowStream<Source>) {
    self.rowStream = rowStream
  }

  public func makeAsyncIterator() -> AsyncIterator {
    AsyncIterator(iterator: rowStream.makeAsyncIterator())
  }

  /// The async iterator that produces typed CSV rows.
  public struct AsyncIterator: AsyncIteratorProtocol {
    private var iterator: CSVRowStream<Source>.AsyncIterator

    init(iterator: CSVRowStream<Source>.AsyncIterator) {
      self.iterator = iterator
    }

    public mutating func next() async throws -> T? {
      guard let rowBytes = try await iterator.next() else {
        return nil
      }
      return T(from: rowBytes.stringFields)
    }
  }
}

/// Extension providing convenience methods for creating typed streams.
extension CSVRowStream {
  /// Converts this row stream into a typed row stream.
  ///
  /// Each row is converted to the specified type. Rows that fail to parse
  /// are skipped.
  ///
  /// - Parameter type: The type to convert rows to.
  /// - Returns: A typed CSV row stream.
  ///
  /// ## Example
  ///
  /// ```swift
  /// let rowStream = CSVRowStream(source: dataStream)
  /// for try await person in rowStream.typed(as: Person.self) {
  ///     print(person.name)
  /// }
  /// ```
  public func typed<T: CSVDecodableRow & Sendable>(as _: T.Type) -> TypedCSVRowStream<T, Source> {
    TypedCSVRowStream(wrapping: self)
  }
}
