import Foundation

/**
 A data source that reads CSV data from an AsyncBytes sequence.

 `AsyncBytesDataSource` provides access to CSV data from asynchronous byte
 sequences, such as those returned by URLSession's bytes(from:) method or
 FileHandle's bytes property.

 Note: This implementation buffers all data at initialization for simplicity
 and compatibility with Swift's concurrency model.

 ## Example with URLSession

 ```swift
 let (bytes, response) = try await URLSession.shared.bytes(from: url)
 let source = try await AsyncBytesDataSource(bytes: bytes)
 // Use with StreamingCSVReader
 ```

 ## Example with FileHandle

 ```swift
 let handle = try FileHandle(forReadingFrom: fileURL)
 let source = try await AsyncBytesDataSource(bytes: handle.bytes)
 // Use with StreamingCSVReader
 ```
 */
public actor AsyncBytesDataSource<S: AsyncSequence & Sendable>: CSVDataSource
where S.Element == UInt8, S.AsyncIterator: Sendable {
  private let data: Data
  private var position: Int = 0
  private let bufferSize: Int

  /// Creates a new data source from an AsyncBytes sequence.
  ///
  /// This initializer collects all bytes from the sequence into memory.
  /// For very large files, consider using FileDataSource instead.
  ///
  /// - Parameters:
  ///   - bytes: The async sequence of bytes to read from.
  ///   - bufferSize: The size of the read buffer in bytes. Defaults to 65536 (64KB).
  public init(bytes: S, bufferSize: Int = 65536) async throws {
    self.bufferSize = bufferSize

    // Collect all bytes into data
    var collectedData = Data()
    var iterator = bytes.makeAsyncIterator()

    while let byte = try await iterator.next() {
      collectedData.append(byte)
    }

    self.data = collectedData
  }

  public func read(maxLength: Int) throws -> Data? {
    guard position < data.count else { return nil }

    // Use the requested maxLength, not limited by bufferSize
    let readLength = min(maxLength, data.count - position)
    let endPosition = position + readLength

    let chunk = data[position..<endPosition]
    position = endPosition

    return chunk.isEmpty ? nil : chunk
  }

  public func close() throws {
    // No resources to clean up
  }
}
