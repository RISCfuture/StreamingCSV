import Foundation

/// A protocol that defines a data source for reading CSV data.
///
/// `CSVDataSource` provides an abstraction over different input sources such as
/// files, network streams, in-memory data, and more. All implementations must be
/// thread-safe and support concurrent access through the Sendable protocol.
///
/// ## Conforming to CSVDataSource
///
/// To create a custom data source, implement the required methods:
///
/// ```swift
/// actor MyCustomDataSource: CSVDataSource {
///     func read(maxLength: Int) async throws -> Data? {
///         // Return up to maxLength bytes, or nil if at end
///     }
///
///     func close() async throws {
///         // Clean up resources
///     }
/// }
/// ```
public protocol CSVDataSource: Sendable {

  /**
   The total number of bytes in the data source, if known.
  
   This property returns the total size of the data source when it can be
   determined upfront (e.g., for files). For streaming sources where the
   total size is unknown, this returns `nil`.
   */
  var totalBytes: Int64? { get async }

  /**
   The number of bytes that have been read from the data source.
  
   This property tracks how many bytes have been consumed, useful for
   progress reporting.
   */
  var bytesRead: Int64 { get async }

  /**
   Reads data from the source.
  
   This method reads up to `maxLength` bytes from the data source. It returns
   `nil` when the end of the data stream is reached. The method may return
   fewer bytes than requested if that's all that's available.
  
   - Parameter maxLength: The maximum number of bytes to read.
   - Returns: Data containing up to `maxLength` bytes, or `nil` if at end.
   - Throws: An error if the read operation fails.
   */
  func read(maxLength: Int) async throws -> Data?

  /**
   Closes the data source and releases any associated resources.
  
   This method should be called when the data source is no longer needed. It's
   automatically called when the reader is deinitialized, but can be called
   explicitly for earlier resource cleanup.
  
   - Throws: An error if closing the source fails.
   */
  func close() async throws
}

extension CSVDataSource {
  /// Default implementation returns nil (unknown total size).
  public var totalBytes: Int64? { nil }

  /// Default implementation returns 0.
  public var bytesRead: Int64 { 0 }
}
