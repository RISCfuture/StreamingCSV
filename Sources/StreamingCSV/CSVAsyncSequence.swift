import Foundation

/// An asynchronous sequence that yields CSV rows as arrays of strings.
///
/// `CSVRowSequence` conforms to `AsyncSequence` and provides iteration over CSV
/// rows without loading the entire file into memory. It supports all standard
/// async sequence operations like `map`, `filter`, `prefix`, etc.
///
/// ## Example
///
/// ```swift
/// let reader = try StreamingCSVReader(url: csvFileURL)
///
/// for try await row in reader.rows() {
///     print("Row: \(row)")
/// }
///
/// // Using enumeration
/// for try await (row, index) in reader.rows().enumerated() {
///     print("Row \(index): \(row)")
/// }
/// ```
public struct CSVRowSequence: AsyncSequence, Sendable {
  public typealias Element = [String]

  private let reader: StreamingCSVReader

  init(reader: StreamingCSVReader) {
    self.reader = reader
  }

  public func makeAsyncIterator() -> AsyncIterator {
    AsyncIterator(reader: reader)
  }

  public struct AsyncIterator: AsyncIteratorProtocol {
    private let reader: StreamingCSVReader

    init(reader: StreamingCSVReader) {
      self.reader = reader
    }

    public mutating func next() async throws -> [String]? {
      try await reader.readRow()
    }
  }
}

/// An asynchronous sequence that yields CSV rows as typed values.
///
/// `TypedCSVRowSequence` conforms to `AsyncSequence` and provides type-safe
/// iteration over CSV rows. Each row is parsed into the specified type that
/// conforms to `CSVRow`.
///
/// ## Example
///
/// ```swift
/// @CSVRowBuilder
/// struct Person {
///     @Field var name: String
///     @Field var age: Int
///     @Field var city: String
/// }
///
/// let reader = try StreamingCSVReader(url: csvFileURL)
///
/// for try await person in reader.rows(as: Person.self) {
///     print("\(person.name) is \(person.age) years old")
/// }
///
/// // Filtering and mapping
/// let adults = reader.rows(as: Person.self)
///     .filter { $0.age >= 18 }
///     .map { $0.name }
///
/// for try await name in adults {
///     print("Adult: \(name)")
/// }
/// ```
public struct TypedCSVRowSequence<T: CSVRow & Sendable>: AsyncSequence, Sendable {
  public typealias Element = T

  private let reader: StreamingCSVReader

  init(reader: StreamingCSVReader) {
    self.reader = reader
  }

  public func makeAsyncIterator() -> AsyncIterator {
    AsyncIterator(reader: reader)
  }

  public struct AsyncIterator: AsyncIteratorProtocol {
    private let reader: StreamingCSVReader

    init(reader: StreamingCSVReader) {
      self.reader = reader
    }

    public mutating func next() async throws -> T? {
      guard let fields = try await reader.readRow() else {
        return nil
      }
      return T(from: fields)
    }
  }
}
