import Foundation

/**
 A data source that reads CSV data from a local file.

 `FileDataSource` provides streaming access to files on the local filesystem
 using `FileHandle`. It's the default data source for backward compatibility
 with existing code.

 ## Example

 ```swift
 let source = try FileDataSource(url: csvFileURL)
 // Use with StreamingCSVReader
 ```
 */
public actor FileDataSource: CSVDataSource {
  private let fileHandle: FileHandle
  private let bufferSize: Int
  private var isAtEnd: Bool = false

  /// Creates a new file data source.
  ///
  /// - Parameters:
  ///   - url: The URL of the file to read. Must be a file URL.
  ///   - bufferSize: The size of the read buffer in bytes. Defaults to 65536
  ///     (64KB).
  /// - Throws: An error if the file cannot be opened for reading.
  public init(url: URL, bufferSize: Int = 65536) throws {
    guard url.isFileURL else {
      throw CSVError.invalidURL
    }
    self.fileHandle = try FileHandle(forReadingFrom: url)
    self.bufferSize = bufferSize
  }

  public func read(maxLength: Int) throws -> Data? {
    guard !isAtEnd else { return nil }

    // Don't limit by bufferSize - use the requested maxLength
    let data = fileHandle.readData(ofLength: maxLength)

    if data.isEmpty {
      isAtEnd = true
      return nil
    }

    return data
  }

  public func close() throws {
    try fileHandle.close()
  }

  deinit {
    try? fileHandle.close()
  }
}
