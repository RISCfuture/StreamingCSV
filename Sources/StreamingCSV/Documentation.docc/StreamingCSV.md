# ``StreamingCSV``

A high-performance, memory-efficient CSV reader and writer for Swift that 
processes files row by row.

@Metadata {
    @DisplayName("StreamingCSV")
    @TitleHeading("Overview")
}

## Overview

StreamingCSV provides a modern Swift API for reading and writing CSV files with
minimal memory overhead. Unlike traditional CSV parsers that load entire files 
into memory, StreamingCSV processes data row by row, making it suitable for 
files of any size.

### Key Features

- **Memory Efficient**: Stream processing architecture handles gigabyte-sized files
- **Type Safe**: Leverage Swift's type system with automatic serialization
- **Swift Concurrency**: Built with async/await and actors
- **Macro Support**: Reduce boilerplate with `@CSVRowBuilder` and `@Field`
- **Robust Parsing**: Handles complex CSV features like quoted fields and multi-line values

## Topics

### Essentials

- <doc:GettingStarted>
- ``StreamingCSVReader``
- ``StreamingCSVWriter``

### Advanced Topics

- <doc:AdvancedUsage>
- <doc:DataSources>

### Type-Safe Operations

- ``CSVRow``
- ``CSVRowBuilder()``
- ``Field()``

### Data Sources

- ``CSVDataSource``
- ``FileDataSource``
- ``URLDataSource``
- ``DataDataSource``
- ``AsyncBytesDataSource``

### Data Destinations

- ``CSVDataDestination``
- ``FileDataDestination``
- ``DataDataDestination``

### Streams

- ``CSVRowSequence``
- ``TypedCSVRowSequence``

### CSV Encoding and Decoding

- ``CSVEncodable``
- ``CSVDecodable``
- ``CSVCodable``

### CSV Parsing

- ``CSVParser``
- ``ByteCSVParser``

### Performance Types

- ``CSVRowBytes``
- ``CSVFieldRange``

### Advanced Data Sources

- ``MemoryMappedFileDataSource``
- ``ParallelCSVReader``

### Error Handling

- ``CSVError``
