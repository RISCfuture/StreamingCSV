# StreamingCSV

[![Build and Test](https://github.com/riscfuture/StreamingCSV/actions/workflows/build.yml/badge.svg)](https://github.com/riscfuture/StreamingCSV/actions/workflows/build.yml)
[![Documentation](https://github.com/riscfuture/StreamingCSV/actions/workflows/documentation.yml/badge.svg)](https://riscfuture.github.io/StreamingCSV/)
[![Swift 5.10+](https://img.shields.io/badge/Swift-5.10+-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-macOS%20|%20iOS%20|%20tvOS%20|%20watchOS%20|%20Linux%20|%20Windows-blue.svg)](https://swift.org)

A high-performance, memory-efficient CSV reader and writer for Swift that 
processes data row by row without loading entire files into memory.

## Features

- 🚀 **Streaming Architecture**: Process gigabyte-sized CSV files with minimal
  memory footprint
- 🔒 **Type Safety**: Use Swift's type system with automatic CSV
  serialization/deserialization
- ⚡ **Swift Concurrency**: Built with async/await for modern Swift apps
- 🎯 **Swift Macros**: Eliminate boilerplate with `@CSVRowBuilder`, `@Field`,
  and `@Fields` macros
- ✨ **Robust Parsing**: Handles quoted fields, escaped characters, and
  multi-line values
- 📦 **Array Fields**: Handle variable-length CSV formats with `@Fields` for
  array properties

## Installation

### Swift Package Manager

Add StreamingCSV to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/riscfuture/StreamingCSV.git", from: "1.0.0")
]
```

Or in Xcode: File → Add Package Dependencies → Enter the repository URL.

## Quick Start

### Reading CSV Files

```swift
import StreamingCSV

// Read from a file
let reader = try StreamingCSVReader(url: csvFileURL)

// Read header
if let headers = try await reader.readRow() {
    print("Headers: \(headers)")
}

// Read data rows
while let row = try await reader.readRow() {
    print("Row: \(row)")
}
```

### Writing CSV Files

```swift
let writer = try StreamingCSVWriter(url: outputURL)

// Write header
try await writer.writeRow(["Name", "Age", "City"])

// Write data
try await writer.writeRow(["Alice", "30", "New York"])
try await writer.writeRow(["Bob", "25", "Los Angeles"])

// Ensure all data is written
try await writer.flush()
```

### Type-Safe CSV with Macros

Define your data structure with the `@CSVRowBuilder` macro for type-safe CSV
operations:

```swift
@CSVRowBuilder
struct Employee {
    @Field var id: Int
    @Field var name: String
    @Field var department: String
    @Field var salary: Double
    @Field var isActive: Bool
}

// Reading typed data
let reader = try StreamingCSVReader(url: csvFileURL)
try await reader.skipRows(count: 1)  // Skip header

while let employee = try await reader.readRow(as: Employee.self) {
    print("\(employee.name) works in \(employee.department)")
}

// Writing typed data
let writer = try StreamingCSVWriter(url: outputURL)
try await writer.writeRow(["ID", "Name", "Department", "Salary", "Active"])

let employees = [
    Employee(id: 1, name: "Alice", department: "Engineering", salary: 100000, isActive: true),
    Employee(id: 2, name: "Bob", department: "Marketing", salary: 80000, isActive: false)
]

for employee in employees {
    try await writer.writeRow(employee)
}
try await writer.flush()
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
// Result: description = nil, discountPrice = 7.99
```

### Working with Array Fields

Use `@Fields` to handle CSV formats with array fields or variable-length rows:

```swift
@CSVRowBuilder
struct TestResult {
    @Field var studentId: String
    @Field var name: String
    @Fields(5) var scores: [Int]  // Fixed 5 score fields with padding
    @Field var grade: String
}

@CSVRowBuilder
struct FlexibleRecord {
    @Field var id: String
    @Field var type: String
    @Fields var tags: [String]  // Collects all remaining fields
}
```

The `@Fields` macro provides two modes:
- `@Fields(n)` - Collects exactly n fields, padding with empty strings on output
- `@Fields` - Collects all remaining fields (must be the last property)

For detailed examples and advanced usage, see the [Advanced Usage](https://riscfuture.github.io/StreamingCSV/documentation/streamingcsv/advancedusage#Working-with-Array-Fields) documentation.

## Reading from Different Sources

```swift
// From URL (downloads first)
let reader = try await StreamingCSVReader(
    downloadURL: URL(string: "https://example.com/data.csv")!
)

// From memory
let csvData = csvString.data(using: .utf8)!
let reader = StreamingCSVReader(data: csvData)

// From async byte stream
let (bytes, _) = try await URLSession.shared.bytes(from: url)
let reader = try await StreamingCSVReader(bytes: bytes)
```

## Writing to Different Destinations

```swift
// To file
let writer = try StreamingCSVWriter(url: fileURL)

// To memory
let (writer, destination) = StreamingCSVWriter.inMemory()
try await writer.writeRow(["Product", "Price"])
try await writer.flush()
let csvData = await destination.getData()

// Append to existing file
let writer = try StreamingCSVWriter(url: fileURL, append: true)
```

## Using AsyncSequence

Iterate through CSV rows using Swift's async sequences:

```swift
let reader = try StreamingCSVReader(url: csvFileURL)

// Basic iteration
for try await row in await reader.rows() {
    print(row)
}

// Skip header and process
let dataRows = await reader.rows().dropFirst()
for try await row in dataRows {
    // Process data rows
}
```

## Supported Types

The following types are automatically supported with `@Field`:

- `String`
- `Int`, `Int8`, `Int16`, `Int32`, `Int64`
- `UInt`, `UInt8`, `UInt16`, `UInt32`, `UInt64`
- `Float`, `Double`
- `Bool` (recognizes: true/false, yes/no, 1/0, y/n, t/f)
- `Data` (Base64 encoded)
- `Optional` (empty strings ↔ nil)

## Documentation

For advanced features and detailed documentation, visit:

- [Full Documentation](https://riscfuture.github.io/StreamingCSV/)
- [Getting Started Guide](https://riscfuture.github.io/StreamingCSV/documentation/streamingcsv/gettingstarted)
- [Advanced Usage](https://riscfuture.github.io/StreamingCSV/documentation/streamingcsv/advancedusage)

Advanced features include:

- Parallel processing for large files
- Memory-mapped file support
- Custom data sources and destinations
- Byte-level parsing for maximum performance
- Adaptive buffer sizing
- Custom delimiters and quote characters
