# Advanced Usage

Learn about advanced features and optimization techniques in StreamingCSV.

## Performance and Optimization

StreamingCSV automatically optimizes parsing performance based on your CSV data characteristics:

- **Byte-level parsing**: Efficient byte-level parser minimizes string allocations
- **Adaptive buffering**: Buffer sizes are dynamically adjusted based on row sizes
- **Zero-copy operations**: Field values are lazily evaluated to minimize memory allocations
- **Optimized parsing**: The parser adapts to CSV characteristics for optimal performance

For most use cases, the default settings provide optimal performance. You can also customize buffer sizes:

```swift
// Larger buffer for better performance with large files
let reader = try StreamingCSVReader(
    url: largeFileURL,
    bufferSize: 256 * 1024  // 256KB buffer
)

// Smaller buffer for reduced memory usage
let writer = try StreamingCSVWriter(
    url: outputURL,
    bufferSize: 8 * 1024  // 8KB buffer
)
```

## Custom Delimiters and Quotes

Work with non-standard CSV formats:

```swift
// Semicolon-delimited file
let reader = try StreamingCSVReader(
    url: csvURL,
    delimiter: ";",
    quote: "'",
    escape: "\\"
)

// Tab-delimited file
let writer = try StreamingCSVWriter(
    url: outputURL,
    delimiter: "\t"
)
```

## Working with Array Fields

Use the `@Fields` macro to handle CSV formats with array fields or variable-length rows:

### Fixed-Size Arrays with Padding

Use `@Fields(n)` to specify that exactly n fields should be collected into an array. When writing back to CSV, the array will be padded with empty strings if it contains fewer than n elements:

```swift
@CSVRowBuilder
struct TestResult {
    @Field var studentId: String
    @Field var name: String
    @Fields(5) var scores: [Int]  // Always 5 score fields
    @Field var grade: String
}

// Reading CSV
let result = TestResult(from: ["001", "Alice", "85", "90", "88", "92", "95", "A"])
// result.scores = [85, 90, 88, 92, 95]

// Partial data
let partial = TestResult(from: ["002", "Bob", "78", "82", "", "", "", "B"])
// partial.scores = [78, 82]  // Empty fields are skipped

// Writing CSV
let row = partial.toCSVRow()
// Returns: ["002", "Bob", "78", "82", "", "", "", "B"]  // Padded to 5 score fields
```

### Variable-Length Arrays

Use parameterless `@Fields` to collect all remaining fields into an array. This must be the last field in your struct:

```swift
@CSVRowBuilder
struct FlexibleRecord {
    @Field var id: String
    @Field var name: String
    @Fields var tags: [String]  // Collects all remaining fields
}

// Reading CSV with varying numbers of tags
let record1 = FlexibleRecord(from: ["001", "Item1", "tag1", "tag2", "tag3"])
// record1.tags = ["tag1", "tag2", "tag3"]

let record2 = FlexibleRecord(from: ["002", "Item2"])
// record2.tags = []  // No extra fields

// Writing CSV - no padding for parameterless @Fields
let row = record1.toCSVRow()
// Returns: ["001", "Item1", "tag1", "tag2", "tag3"]
```

### Combining Fixed and Variable Arrays

You can use both `@Fields(n)` and `@Fields` in the same struct for complex CSV formats:

```swift
@CSVRowBuilder
struct DataRecord {
    @Field var id: String
    @Field var type: String
    @Fields(3) var primaryValues: [Double]  // Fixed 3 slots with padding
    @Fields var metadata: [String]          // All remaining fields
}

// Reading complex CSV
let record = DataRecord(from: ["001", "TypeA", "1.5", "2.5", "3.5", "meta1", "meta2", "meta3"])
// record.primaryValues = [1.5, 2.5, 3.5]
// record.metadata = ["meta1", "meta2", "meta3"]

// Writing with padding for fixed fields only
let sparse = DataRecord(from: ["002", "TypeB", "4.5", "", "", "extra"])
let row = sparse.toCSVRow()
// Returns: ["002", "TypeB", "4.5", "", "", "extra"]  // primaryValues padded to 3
```

## Using AsyncSequence for Advanced Iteration

StreamingCSV provides AsyncSequence support for more idiomatic Swift iteration with advanced operators:

```swift
let reader = try StreamingCSVReader(url: csvFileURL)

// Basic iteration with for-await-in
for try await row in await reader.rows() {
    print("Row: \(row)")
}

// Skip header using dropFirst
let dataRows = await reader.rows().dropFirst()
for try await row in dataRows {
    // Process data rows
}

// Filter rows
let longRows = await reader.rows()
    .filter { $0.count > 5 }
for try await row in longRows {
    print("Long row: \(row)")
}

// Take only first N rows
let firstTenRows = await reader.rows().prefix(10)
for try await row in firstTenRows {
    print("Row: \(row)")
}

// Typed iteration with filtering
@CSVRowBuilder
struct Person {
    @Field var name: String
    @Field var age: Int
}

// Skip header and iterate typed rows
try await reader.skipRows(count: 1)
for try await person in await reader.rows(as: Person.self) {
    print("\(person.name) is \(person.age) years old")
}

// Filter typed rows
let adults = await reader.rows(as: Person.self)
    .filter { $0.age >= 18 }
for try await adult in adults {
    print("\(adult.name) is an adult")
}
```

## Manual CSVRow Implementation

For complex scenarios where the macro approach isn't sufficient, implement `CSVRow` manually:

```swift
struct Person: CSVRow {
    let firstName: String
    let lastName: String
    let age: Int
    let email: String?
    
    init?(from fields: [String]) {
        guard fields.count >= 3 else { return nil }
        
        self.firstName = fields[0]
        self.lastName = fields[1]
        
        guard let age = Int(fields[2]) else { return nil }
        self.age = age
        
        // Optional email field
        self.email = fields.count > 3 && !fields[3].isEmpty ? fields[3] : nil
    }
    
    func toCSVRow() -> [String] {
        [firstName, lastName, String(age), email ?? ""]
    }
}
```

## Custom Type Encoding/Decoding

Extend your types to support CSV serialization:

```swift
struct PhoneNumber: CSVCodable {
    let countryCode: String
    let number: String
    
    init?(csvString: String) {
        let parts = csvString.split(separator: "-")
        guard parts.count == 2 else { return nil }
        self.countryCode = String(parts[0])
        self.number = String(parts[1])
    }
    
    var csvString: String {
        "\(countryCode)-\(number)"
    }
}

// Now you can use PhoneNumber in CSV rows
@CSVRowBuilder
struct Contact {
    @Field var name: String
    @Field var phone: PhoneNumber
    @Field var email: String
}
```

## Byte-Level Parsing for Maximum Performance

For scenarios requiring maximum performance, use the byte-level parser directly:

```swift
// Use ByteCSVParser for zero-copy parsing
let parser = ByteCSVParser()
let data = csvString.data(using: .utf8)!

if let (rowBytes, consumed) = parser.parseRow(from: data) {
    // Access fields lazily - strings created only when needed
    for fieldRange in rowBytes.fields {
        if let value = fieldRange.extractString(from: data) {
            print("Field: \(value)")
        }
    }
    
    // Or access specific fields by index
    if let firstField = rowBytes.field(at: 0, from: data) {
        print("First field: \(firstField)")
    }
}
```

## Parallel Processing for Large Files

For maximum performance with large CSV files, use `ParallelCSVReader` to leverage multiple CPU cores:

```swift
let reader = ParallelCSVReader(
    url: fileURL,
    parallelism: 4  // Use 4 concurrent workers
)

let result = try await reader.readAllRows()
print("Processed \(result.totalRows) rows in \(result.processingTime) seconds")

// Process the chunks
for chunk in result.chunks {
    for row in chunk {
        // Process each row
        print(row)
    }
}
```

The parallel reader automatically:
- Memory-maps the file for efficient access
- Divides the file into chunks aligned with row boundaries
- Processes chunks concurrently using multiple workers
- Falls back to sequential processing for small files

## Memory-Mapped File Processing

For very large files, use memory-mapped I/O to reduce memory pressure:

```swift
let dataSource = try MemoryMappedFileDataSource(url: fileURL)
let reader = StreamingCSVReader(
    dataSource: dataSource,
    delimiter: ",",
    quote: "\"",
    escape: "\"",
    encoding: .utf8
)

// File is mapped to virtual memory, loaded on demand
while let row = try await reader.readRow() {
    // Process row - only accessed pages are loaded into memory
}
```

Memory mapping provides:
- Zero-copy access to file contents
- Automatic paging by the OS
- Minimal memory footprint even for gigabyte-sized files
- Shared memory across multiple readers

## Custom Data Sources

Create custom data sources by conforming to the `CSVDataSource` protocol:

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

Similarly, create custom destinations by conforming to `CSVDataDestination`:

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

## Error Handling Strategies

Implement robust error handling for production use:

```swift
do {
    let reader = try await StreamingCSVReader(
        downloadURL: csvURL
    )
    
    // Process with row-level error handling
    var errorCount = 0
    let maxErrors = 10
    
    for try await row in await reader.rows() {
        do {
            // Process row
            try processRow(row)
        } catch {
            errorCount += 1
            print("Error processing row: \(error)")
            
            if errorCount >= maxErrors {
                throw CSVError.tooManyErrors
            }
        }
    }
} catch CSVError.invalidURL {
    print("Invalid URL provided")
} catch CSVError.networkError(let underlying) {
    print("Network download failed: \(underlying)")
} catch CSVError.encodingError {
    print("CSV encoding error")
} catch {
    print("Unexpected error: \(error)")
}
```

## Best Practices

### Memory Management
1. Use streaming for large files instead of loading everything into memory
2. Choose appropriate buffer sizes based on your data and memory constraints
3. Consider memory-mapped files for very large datasets
4. Use parallel processing for CPU-bound operations on large files

### Performance Optimization
1. Use byte-level parsing when you need maximum performance
2. Enable parallel processing for files larger than a few megabytes
3. Let the adaptive buffer strategy optimize buffer sizes automatically
4. Consider memory mapping for random access patterns

### Error Handling
1. Always call `flush()` on writers to ensure all data is saved
2. Use defer blocks to ensure proper cleanup
3. Implement retry logic for network sources
4. Validate data types when using typed rows

### Type Safety
1. Prefer `@CSVRowBuilder` macros for compile-time safety
2. Use optionals for fields that might be empty
3. Implement custom `CSVCodable` types for complex data
4. Validate data in custom `init?(from:)` implementations