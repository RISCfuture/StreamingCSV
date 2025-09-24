import Foundation

/**
 A data destination that writes CSV data to an in-memory Data buffer.

 `DataDataDestination` accumulates all written CSV data in memory. This is
 useful for generating CSV content that will be sent to an API, stored in a
 database, or processed further in memory.

 ## Example

 ```swift
 let destination = DataDataDestination()
 // Use with StreamingCSVWriter
 // ...
 let csvData = await destination.getData()
 ```
 */
public actor DataDataDestination: CSVDataDestination {
  private var data: Data

  /// Creates a new in-memory data destination.
  public init() {
    self.data = Data()
  }

  /// Returns the accumulated CSV data.
  ///
  /// - Returns: All data written to this destination so far.
  public func getData() -> Data {
    return data
  }

  public func write(_ data: Data) throws {
    self.data.append(data)
  }

  public func flush() throws {
    // No buffering for in-memory data, so nothing to flush
  }

  public func close() throws {
    // No resources to clean up for in-memory data
  }
}
