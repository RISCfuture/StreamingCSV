import Foundation

/**
 A data source that reads CSV data from in-memory `Data`.

 `DataDataSource` provides access to CSV content that's already loaded in memory
 as a Data object. This is useful for processing CSV data received from APIs,
 generated programmatically, or loaded from embedded resources.
 
 ## Example
 
 ```swift
 let csvData = "Name,Age\nAlice,30\nBob,25".data(using: .utf8)!
 let source = DataDataSource(data: csvData)
 // Use with StreamingCSVReader
 ```
 */
public actor DataDataSource: CSVDataSource {
    private let data: Data
    private var position: Int = 0
    private let bufferSize: Int

    /**
     Creates a new data source from in-memory `Data`.

     - Parameters:
       - data: The CSV data to read from.
       - bufferSize: The size of the read buffer in bytes. Defaults to 65536
         (64KB).
     */
    public init(data: Data, bufferSize: Int = 65536) {
        self.data = data
        self.bufferSize = bufferSize
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
        // No resources to clean up for in-memory data
    }
}
