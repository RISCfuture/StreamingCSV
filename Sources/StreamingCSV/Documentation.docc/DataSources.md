# Working with Data Sources

Learn how to read and write CSV data from various sources including files, 
networks, and memory.

## Overview

StreamingCSV provides a flexible architecture for reading CSV data from multiple
sources and writing to various destinations. This is achieved through the
``CSVDataSource`` and ``CSVDataDestination`` protocols, which abstract the 
underlying I/O operations.

## Reading from Different Sources

### Local Files

The traditional way to read CSV files from the local filesystem:

```swift
let reader = try StreamingCSVReader(url: csvFileURL)

// Process rows
while let row = try await reader.readRow() {
    print(row)
}
```

### Network URLs

Download and parse CSV data directly from HTTP/HTTPS URLs:

```swift
// Simple download
let reader = try await StreamingCSVReader(
    downloadURL: URL(string: "https://api.example.com/data.csv")!
)

// With progress tracking
let reader = try await StreamingCSVReader(
    downloadURL: csvURL,
    progressHandler: { bytesReceived, totalBytes in
        if let total = totalBytes {
            let percent = Double(bytesReceived) / Double(total) * 100
            print("Progress: \(percent.formatted(.number.precision(.fractionLength(1))))%")
        }
    }
)
```

### In-Memory Data

Process CSV data that's already loaded in memory, useful for data received from 
APIs or generated programmatically:

```swift
let csvString = """
Name,Age,City
Alice,30,New York
Bob,25,Los Angeles
"""

let data = csvString.data(using: .utf8)!
let reader = StreamingCSVReader(data: data)

// Process the CSV data
for try await row in await reader.rows() {
    print(row)
}
```

### Async Byte Streams

Work with asynchronous byte sequences for true streaming without loading entire
files into memory:

```swift
// Using URLSession's bytes stream
let (bytes, response) = try await URLSession.shared.bytes(from: csvURL)
guard let httpResponse = response as? HTTPURLResponse,
      httpResponse.statusCode == 200 else {
    throw URLError(.badServerResponse)
}

let reader = try await StreamingCSVReader(bytes: bytes)

// Using FileHandle's bytes property (macOS 12.0+, iOS 15.0+)
let handle = try FileHandle(forReadingFrom: fileURL)
let reader = try await StreamingCSVReader(bytes: handle.bytes)
```

## Writing to Different Destinations

### Files

Write CSV data to local files:

```swift
let writer = try StreamingCSVWriter(url: outputURL)

try await writer.writeRow(["Name", "Age", "City"])
try await writer.writeRow(["Alice", "30", "New York"])
try await writer.flush()
```

### In-Memory Buffers

Generate CSV data in memory for sending to APIs or further processing:

```swift
// Create an in-memory writer
let (writer, destination) = StreamingCSVWriter.inMemory()

// Write CSV data
try await writer.writeRow(["Product", "Price", "Stock"])
try await writer.writeRow(["Laptop", "999.99", "15"])
try await writer.writeRow(["Phone", "699.99", "32"])
try await writer.flush()

// Get the generated CSV data
let csvData = await destination.getData()

// Convert to string if needed
let csvString = String(data: csvData, encoding: .utf8)!

// Send to API, save to database, etc.
try await uploadToAPI(csvData)
```

## Custom Data Sources

You can create custom data sources by conforming to the ``CSVDataSource``
protocol:

```swift
actor CustomDataSource: CSVDataSource {
    private var position = 0
    private let totalSize: Int
    
    func read(maxLength: Int) async throws -> Data? {
        guard position < totalSize else { return nil }
        
        // Your custom logic to read data
        let data = try await fetchDataChunk(
            offset: position, 
            length: min(maxLength, totalSize - position)
        )
        
        position += data.count
        return data
    }
    
    func close() async throws {
        // Clean up resources
    }
}

// Use with StreamingCSVReader
let customSource = CustomDataSource()
let reader = StreamingCSVReader(
    dataSource: customSource,
    delimiter: ",",
    quote: "\"",
    escape: "\"",
    encoding: .utf8
)
```

## Custom Data Destinations

Similarly, create custom destinations by conforming to ``CSVDataDestination``:

```swift
actor CloudStorageDestination: CSVDataDestination {
    private let uploadSession: UploadSession
    private var buffer = Data()
    private let bufferThreshold = 1024 * 1024 // 1MB
    
    func write(_ data: Data) async throws {
        buffer.append(data)
        
        // Upload in chunks when buffer is large enough
        if buffer.count >= bufferThreshold {
            try await uploadChunk(buffer)
            buffer.removeAll()
        }
    }
    
    func flush() async throws {
        if !buffer.isEmpty {
            try await uploadChunk(buffer)
            buffer.removeAll()
        }
    }
    
    func close() async throws {
        try await flush()
        try await uploadSession.finalize()
    }
}
```

## Performance Considerations

### Buffer Sizes

Adjust buffer sizes based on your use case:

```swift
// Larger buffer for better performance with large files
let reader = try StreamingCSVReader(
    url: largeFileURL,
    bufferSize: 256 * 1024  // 256KB
)

// Smaller buffer for reduced memory usage
let reader = try StreamingCSVReader(
    url: smallFileURL,
    bufferSize: 8 * 1024   // 8KB
)
```

### Network Sources

When reading from network sources:

- `URLDataSource` downloads the entire file before processing begins
- `AsyncBytesDataSource` with `URLSession.bytes` provides true streaming but 
  buffers data for compatibility
- Consider file size and network conditions when choosing an approach

### Advanced Data Sources

For specialized performance requirements, StreamingCSV provides advanced data sources:

#### Memory-Mapped Files

Use ``MemoryMappedFileDataSource`` for zero-copy access to large files:

```swift
let dataSource = try MemoryMappedFileDataSource(url: largeFileURL)
let reader = StreamingCSVReader(
    dataSource: dataSource,
    delimiter: ",",
    quote: "\"",
    escape: "\"",
    encoding: .utf8
)
```

Memory mapping provides direct access to file contents without loading them into memory,
ideal for processing very large CSV files efficiently.

#### Parallel Processing

For maximum performance with large files, use ``ParallelCSVReader``:

```swift
let parallelReader = ParallelCSVReader(
    url: csvFileURL,
    parallelism: 4  // Process with 4 concurrent workers
)

let results = try await parallelReader.readAllRows()
for chunk in results.chunks {
    for row in chunk {
        // Process row
    }
}
```

Parallel processing splits the file into chunks and processes them concurrently,
significantly reducing processing time for large datasets on multi-core systems.

### Memory Sources

- **DataDataSource** is ideal for small to medium CSV data already in memory
- For large datasets, prefer file-based or streaming approaches
- In-memory destinations are convenient but use more memory than file-based 
destinations

## Error Handling

Different data sources may throw different errors:

```swift
do {
    let reader = try await StreamingCSVReader(
        downloadURL: csvURL
    )
    // Process CSV
} catch CSVError.invalidURL {
    print("Invalid URL provided")
} catch CSVError.networkError {
    print("Network download failed")
} catch CSVError.encodingError {
    print("CSV encoding error")
} catch {
    print("Unexpected error: \(error)")
}
```
