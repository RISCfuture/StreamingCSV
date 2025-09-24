import Foundation

/// A protocol that defines a data destination for writing CSV data.
///
/// `CSVDataDestination` provides an abstraction over different output destinations
/// such as files, in-memory buffers, output streams, and more. All implementations
/// must be thread-safe and support concurrent access through the Sendable protocol.
///
/// ## Conforming to CSVDataDestination
///
/// To create a custom data destination, implement the required methods:
///
/// ```swift
/// actor MyCustomDataDestination: CSVDataDestination {
///     func write(_ data: Data) async throws {
///         // Write data to the destination
///     }
///
///     func flush() async throws {
///         // Flush any buffered data
///     }
///
///     func close() async throws {
///         // Clean up resources
///     }
/// }
/// ```
///
/// ## Built-in Implementations
///
/// StreamingCSV provides several built-in data destinations:
/// - ``FileDataDestination``: Writes to local files
/// - ``DataDataDestination``: Writes to in-memory Data buffers
public protocol CSVDataDestination: Sendable {
  /**
   Writes data to the destination.
  
   This method writes the provided data to the output destination. The data
   may be buffered internally for performance reasons. Call ``flush()`` to
   ensure all data is written.
  
   - Parameter data: The data to write.
   - Throws: An error if the write operation fails.
   */
  func write(_ data: Data) async throws

  /**
   Flushes any buffered data to the destination.
  
   This method ensures that all previously written data is actually sent to
   the underlying destination. It's automatically called when the destination
   is closed, but can be called explicitly for immediate writes.
  
   - Throws: An error if the flush operation fails.
   */
  func flush() async throws

  /**
   Closes the data destination and releases any associated resources.
  
   This method should be called when the destination is no longer needed.
   It automatically flushes any remaining buffered data before closing.
  
   - Throws: An error if closing the destination fails.
   */
  func close() async throws
}
