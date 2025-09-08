# Getting Started

Learn how to use StreamingCSV for common CSV processing tasks.

## Reading CSV Files

StreamingCSV can read CSV data from various sources including local files, 
network URLs, in-memory data, and async byte streams.

### Reading from Files

The simplest way to read a CSV file is using `readRow()`, which returns each row 
as an array of strings:

```swift
import StreamingCSV

let reader = try StreamingCSVReader(url: csvFileURL)

// Read header row
if let headers = try await reader.readRow() {
    print("Headers: \(headers)")
}

// Read data rows
while let row = try await reader.readRow() {
    print("Row: \(row)")
}
```

### Reading from Other Sources

```swift
// From network URL
let reader = try await StreamingCSVReader(
    downloadURL: URL(string: "https://example.com/data.csv")!
)

// From in-memory data
let csvData = csvString.data(using: .utf8)!
let reader = StreamingCSVReader(data: csvData)

// From async byte stream (e.g., URLSession)
let (bytes, _) = try await URLSession.shared.bytes(from: url)
let reader = try await StreamingCSVReader(bytes: bytes)
```

### Type-Safe Reading with Macros

For type safety, define a struct with the `@CSVRowBuilder` macro:

```swift
@CSVRowBuilder
struct Employee {
    @Field var id: Int
    @Field var name: String
    @Field var department: String
    @Field var salary: Double
    @Field var isActive: Bool
}

let reader = try StreamingCSVReader(url: csvFileURL)

// Skip header if present
try await reader.skipRows(count: 1)

// Read typed rows
while let employee = try await reader.readRow(as: Employee.self) {
    print("\(employee.name) works in \(employee.department)")
}
```

### Handling Optional Fields

Optional properties are automatically handled - empty CSV fields become `nil`:

```swift
@CSVRowBuilder
struct Product {
    @Field var id: Int
    @Field var name: String
    @Field var description: String?  // Can be empty
    @Field var price: Double
    @Field var discountPrice: Double?  // Can be empty
}

// CSV: "1,Widget,,9.99,7.99"
// description will be nil, discountPrice will be 7.99
```

## Writing CSV Files

StreamingCSV can write CSV data to files or in-memory buffers.

### Writing to Files

Write CSV data using string arrays:

```swift
let writer = try StreamingCSVWriter(url: outputURL)

// Write header
try await writer.writeRow(["ID", "Name", "Email", "Age"])

// Write data
try await writer.writeRow(["1", "Alice Smith", "alice@example.com", "28"])
try await writer.writeRow(["2", "Bob Jones", "bob@example.com", "35"])

// Ensure all data is written
try await writer.flush()
```

### Writing to Memory

Generate CSV data in memory for APIs or further processing:

```swift
let (writer, destination) = StreamingCSVWriter.inMemory()

try await writer.writeRow(["Product", "Price"])
try await writer.writeRow(["Laptop", "999.99"])
try await writer.flush()

// Get the CSV data
let csvData = await destination.getData()
```

### Type-Safe Writing

Write typed data using structs:

```swift
@CSVRowBuilder
struct Customer {
    @Field var id: Int
    @Field var name: String
    @Field var email: String
    @Field var creditLimit: Double?
}

let writer = try StreamingCSVWriter(url: outputURL)

// Write header
try await writer.writeRow(["ID", "Name", "Email", "Credit Limit"])

// Write typed data
let customers = [
    Customer(id: 1, name: "Alice", email: "alice@example.com", creditLimit: 5000),
    Customer(id: 2, name: "Bob", email: "bob@example.com", creditLimit: nil)
]

for customer in customers {
    try await writer.writeRow(customer)
}

try await writer.flush()
```

## Common Use Cases

### Processing Large Files

StreamingCSV processes files row by row, making it suitable for large files:

```swift
let reader = try StreamingCSVReader(url: largeFileURL)

// Process rows without loading entire file into memory
while let row = try await reader.readRow() {
    // Each row is processed individually
    try await processRow(row)
}
```

### Skipping Headers

Skip header rows before processing data:

```swift
let reader = try StreamingCSVReader(url: csvFileURL)

// Skip header row
try await reader.skipRows(count: 1)

// Process data rows
while let row = try await reader.readRow() {
    // Process data rows only
}
```

### Appending to Existing Files

Add rows to an existing CSV file:

```swift
let writer = try StreamingCSVWriter(
    url: existingFileURL,
    append: true
)

try await writer.writeRow(["New", "Data", "Row"])
try await writer.flush()
```

### Using AsyncSequence

Iterate through CSV rows using Swift's async sequences:

```swift
let reader = try StreamingCSVReader(url: csvFileURL)

// Iterate using for-await-in
for try await row in await reader.rows() {
    print("Row: \(row)")
}

// Skip header using dropFirst
let dataRows = await reader.rows().dropFirst()
for try await row in dataRows {
    // Process data rows only
}
```

## Supported Types

The following types have built-in CSV support when used with `@Field`:

- `String`
- `Int`, `Int8`, `Int16`, `Int32`, `Int64`
- `UInt`, `UInt8`, `UInt16`, `UInt32`, `UInt64`
- `Float`, `Double`
- `Bool` (recognizes: true/false, yes/no, 1/0, y/n, t/f)
- `Data` (Base64 encoded)
- `Optional` (empty strings ↔ nil)

## Error Handling

Handle common CSV processing errors:

```swift
do {
    let reader = try StreamingCSVReader(url: csvFileURL)
    
    while let row = try await reader.readRow() {
        // Process row
    }
} catch CSVError.fileNotFound {
    print("CSV file not found")
} catch CSVError.encodingError {
    print("Unable to decode CSV with specified encoding")
} catch {
    print("Error: \(error)")
}
```

## Next Steps

- Learn about <doc:DataSources> for working with different data sources
- Explore <doc:AdvancedUsage> for performance optimization and advanced features
- See the API documentation for ``StreamingCSVReader`` and ``StreamingCSVWriter``