import Foundation

/**
 A data source that uses memory mapping for efficient file access.

 Memory mapping provides zero-copy access to file contents, making it ideal for
 large CSV files that need to be processed efficiently.
 */
public actor MemoryMappedFileDataSource: CSVDataSource {
  // MARK: - Properties

  private let data: Data
  private var currentOffset: Int = 0
  private let bufferSize: Int

  // MARK: - Computed Properties

  /// The total size of the file.
  public var fileSize: Int { data.count }

  var canParallelProcess: Bool {
    // Files larger than 10MB are good candidates for parallel processing
    return data.count > 10 * 1024 * 1024
  }

  // MARK: - Initialization

  /// Creates a new data source.
  ///
  /// - Parameter url: The URL containing the data.
  /// - Parameter bufferSize: The size of the buffer, in bytes.
  /// - Throws: If the URL is not a file URL.
  public init(url: URL, bufferSize: Int = 65536) throws {
    guard url.isFileURL else {
      throw CSVError.invalidURL
    }

    // Memory map the file
    self.data = try Data(contentsOf: url, options: .mappedIfSafe)
    self.bufferSize = bufferSize
  }

  // MARK: - Methods

  public func read(maxLength: Int) throws -> Data? {
    guard currentOffset < data.count else { return nil }

    let readLength = min(maxLength, data.count - currentOffset)
    let endOffset = currentOffset + readLength

    // Return a slice of the memory-mapped data (zero-copy)
    let slice = data[currentOffset..<endOffset]
    currentOffset = endOffset

    return slice
  }

  func createSlice(from startOffset: Int, to endOffset: Int) -> Data {
    guard startOffset < data.count else { return Data() }
    let actualEnd = min(endOffset, data.count)
    return data[startOffset..<actualEnd]
  }

  public func close() throws {
    // Memory-mapped data is automatically released when Data is deallocated
  }
}
