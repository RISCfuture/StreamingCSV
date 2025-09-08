import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/**
 A streaming CSV reader that efficiently processes large CSV files row by row.

 `StreamingCSVReader` uses buffered I/O to read CSV files without loading the
 entire file into memory, making it suitable for processing large datasets. It
 supports both raw string array access and type-safe parsing through the
 ``CSVRow`` protocol.

 The reader is an actor, ensuring thread-safe access in concurrent environments.

 ## Topics

 ### Creating a Reader

 - ``init(url:delimiter:quote:escape:encoding:bufferSize:)``

 ### Reading Raw Data

 - ``readRow()``

 ### Reading Typed Data

 - ``readRow(as:)``

 ## Example

 ```swift
 let reader = try StreamingCSVReader(url: csvFileURL)

 // Read raw string arrays
 while let row = try await reader.readRow() {
 print(row)
 }

 // Or read typed rows
 while let person = try await reader.readRow(as: Person.self) {
 print(person.name)
 }
 ```
 */
public actor StreamingCSVReader {
    private let dataSource: any CSVDataSource
    private let parser: CSVParser
    private let byteParser: ByteCSVParser
    private let bufferStrategy: AdaptiveBufferStrategy
    private var byteBuffer: CSVByteBuffer
    private let bufferSize: Int
    private let encoding: String.Encoding
    private var isAtEnd: Bool
    private var characteristics: CSVCharacteristics

    /**
     Creates a new streaming CSV reader for the specified file.

     - Parameters:
     - url: The URL of the CSV file to read.
     - delimiter: The character used to separate fields. Defaults to comma
     (`,`).
     - quote: The character used to quote fields. Defaults to double quote
     (`"`).
     - escape: The character used to escape quotes. Defaults to double quote
     (`"`).
     - encoding: The string encoding to use when reading the file. Defaults to
     UTF-8.
     - bufferSize: The size of the read buffer in bytes. Defaults to 65536
     (64KB).
     - Throws: An error if the file cannot be opened for reading.
     */
    public init(url: URL,
                delimiter: Character = ",",
                quote: Character = "\"",
                escape: Character = "\"",
                encoding: String.Encoding = .utf8,
                bufferSize: Int = 65536,
    ) throws {
        self.dataSource = try FileDataSource(url: url, bufferSize: bufferSize)
        self.parser = CSVParser(delimiter: delimiter, quote: quote, escape: escape)
        self.byteParser = ByteCSVParser(delimiter: delimiter, quote: quote, escape: escape)
        self.bufferStrategy = AdaptiveBufferStrategy()
        self.byteBuffer = CSVByteBuffer(capacity: bufferSize)
        self.encoding = encoding
        self.bufferSize = bufferSize
        self.isAtEnd = false
        self.characteristics = CSVCharacteristics()
    }

    /**
     Creates a new streaming CSV reader that downloads from a network URL.

     This initializer downloads CSV data from an HTTP or HTTPS URL. The download
     happens asynchronously before parsing begins.

     - Parameters:
     - url: The URL to download CSV data from.
     - delimiter: The character used to separate fields. Defaults to comma (`,`).
     - quote: The character used to quote fields. Defaults to double quote (`"`).
     - escape: The character used to escape quotes. Defaults to double quote (`"`).
     - encoding: The string encoding to use when reading the file. Defaults to UTF-8.
     - bufferSize: The size of the read buffer in bytes. Defaults to 65536 (64KB).
     - session: The URLSession to use for downloading. Defaults to shared session.
     - progressHandler: Optional closure called with download progress.
     - Throws: An error if the download fails.
     */
    public init(downloadURL url: URL,
                delimiter: Character = ",",
                quote: Character = "\"",
                escape: Character = "\"",
                encoding: String.Encoding = .utf8,
                bufferSize: Int = 65536,
                session: URLSession = .shared,
                progressHandler: (@Sendable (Int64, Int64?) -> Void)? = nil) async throws {
        self.dataSource = try await URLDataSource(
            url: url,
            bufferSize: bufferSize,
            session: session,
            progressHandler: progressHandler
        )
        self.parser = CSVParser(delimiter: delimiter, quote: quote, escape: escape)
        self.byteParser = ByteCSVParser(delimiter: delimiter, quote: quote, escape: escape)
        self.bufferStrategy = AdaptiveBufferStrategy()
        self.byteBuffer = CSVByteBuffer(capacity: bufferSize)
        self.encoding = encoding
        self.bufferSize = bufferSize
        self.isAtEnd = false
        self.characteristics = CSVCharacteristics()
    }

    /**
     Creates a new streaming CSV reader from in-memory Data.

     This initializer processes CSV data that's already loaded in memory.

     - Parameters:
     - data: The CSV data to read.
     - delimiter: The character used to separate fields. Defaults to comma (`,`).
     - quote: The character used to quote fields. Defaults to double quote (`"`).
     - escape: The character used to escape quotes. Defaults to double quote (`"`).
     - encoding: The string encoding to use when reading the data. Defaults to UTF-8.
     - bufferSize: The size of the read buffer in bytes. Defaults to 65536 (64KB).
     */
    public init(data: Data,
                delimiter: Character = ",",
                quote: Character = "\"",
                escape: Character = "\"",
                encoding: String.Encoding = .utf8,
                bufferSize: Int = 65536) {
        self.dataSource = DataDataSource(data: data, bufferSize: bufferSize)
        self.parser = CSVParser(delimiter: delimiter, quote: quote, escape: escape)
        self.byteParser = ByteCSVParser(delimiter: delimiter, quote: quote, escape: escape)
        self.bufferStrategy = AdaptiveBufferStrategy()
        self.byteBuffer = CSVByteBuffer(capacity: bufferSize)
        self.encoding = encoding
        self.bufferSize = bufferSize
        self.isAtEnd = false
        self.characteristics = CSVCharacteristics()
    }

    /**
     Creates a new streaming CSV reader from an AsyncBytes sequence.

     This initializer enables true streaming of large files without loading them
     entirely into memory. It works with URLSession's bytes(from:) method and
     FileHandle's bytes property.

     - Parameters:
     - bytes: The async sequence of bytes to read from.
     - delimiter: The character used to separate fields. Defaults to comma (`,`).
     - quote: The character used to quote fields. Defaults to double quote (`"`).
     - escape: The character used to escape quotes. Defaults to double quote (`"`).
     - encoding: The string encoding to use when reading the bytes. Defaults to UTF-8.
     - bufferSize: The size of the read buffer in bytes. Defaults to 65536 (64KB).
     */
    public init<S: AsyncSequence & Sendable>(bytes: S,
                                             delimiter: Character = ",",
                                             quote: Character = "\"",
                                             escape: Character = "\"",
                                             encoding: String.Encoding = .utf8,
                                             bufferSize: Int = 65536) async throws where S.Element == UInt8, S.AsyncIterator: Sendable {
        self.dataSource = try await AsyncBytesDataSource(bytes: bytes, bufferSize: bufferSize)
        self.parser = CSVParser(delimiter: delimiter, quote: quote, escape: escape)
        self.byteParser = ByteCSVParser(delimiter: delimiter, quote: quote, escape: escape)
        self.bufferStrategy = AdaptiveBufferStrategy()
        self.byteBuffer = CSVByteBuffer(capacity: bufferSize)
        self.encoding = encoding
        self.bufferSize = bufferSize
        self.isAtEnd = false
        self.characteristics = CSVCharacteristics()
    }

    // MARK: - Methods

    // Helper to create field ranges from parsed strings (for fast path compatibility)
    private static func createFieldRangesFromStrings(_ fields: [String], in data: Data) -> [CSVFieldRange] {
        var ranges: [CSVFieldRange] = []
        var searchIndex = 0

        for field in fields {
            if let fieldData = field.data(using: .utf8) {
                // Find this field's data in the original data starting from searchIndex
                if let range = data[searchIndex...].range(of: fieldData) {
                    let absoluteStart = range.lowerBound
                    let absoluteEnd = range.upperBound
                    ranges.append(CSVFieldRange(
                        start: absoluteStart,
                        end: absoluteEnd,
                        isQuoted: false
                    ))
                    searchIndex = absoluteEnd + 1 // Skip delimiter
                } else {
                    // Fallback: create empty range
                    ranges.append(CSVFieldRange(start: searchIndex, end: searchIndex, isQuoted: false))
                }
            } else {
                // Fallback: create empty range
                ranges.append(CSVFieldRange(start: searchIndex, end: searchIndex, isQuoted: false))
            }
        }

        return ranges
    }

    /**
     Reads the next row using the high-performance byte parser.

     This method provides direct access to the byte-level parsing results,
     allowing for lazy string conversion and better memory efficiency.

     - Returns: A `CSVRowBytes` containing field ranges, or `nil` if EOF is reached.
     - Throws: An error if reading fails.
     */
    public func readRowBytes() async throws -> CSVRowBytes? {
        // Use byte parser for better performance
        while true {
            // Fill buffer if empty
            if byteBuffer.readableBytes == 0 && !isAtEnd {
                try await fillByteBuffer()
            }

            // Check if we have enough data in the byte buffer
            if byteBuffer.readableBytes > 0 {
                if let data = byteBuffer.peek(count: byteBuffer.readableBytes) {
                    var parseResult: (row: CSVRowBytes, consumed: Int)?
                    if let result = byteParser.parseRow(from: data) {
                        parseResult = (result.row, result.consumedBytes)
                    }

                    // Process the result
                    if let (row, consumed) = parseResult {
                        byteBuffer.skip(count: consumed)

                        // Update characteristics and buffer strategy
                        characteristics.observe(rowBytes: row, rawSize: consumed)
                        _ = await bufferStrategy.recordRow(size: consumed)

                        return row
                    }
                }
            }

            // Need more data - compact buffer to make room for more data
            // This ensures partial rows at the end of the buffer are preserved
            if byteBuffer.readableBytes > 0 && byteBuffer.readableBytes < byteBuffer.capacity / 2 {
                byteBuffer.compact()
            }

            if isAtEnd {
                // Process any remaining data
                if byteBuffer.readableBytes > 0 {
                    if let data = byteBuffer.read(count: byteBuffer.readableBytes) {
                        if let (row, _) = byteParser.parseRow(from: data) {
                            return row
                        }
                    }
                }
                return nil
            }

            // Fill buffer with more data
            try await fillByteBuffer()
        }
    }

    /**
     Reads the next row with lazy field evaluation.

     Fields are only converted to strings when accessed, reducing memory overhead.

     - Returns: A lazy row wrapper, or `nil` if EOF is reached.
     */
    public func readRowLazy() async throws -> CSVRowBytes? {
        return try await readRowBytes()
    }

    private func fillByteBuffer() async throws {
        let recommendedSize = await bufferStrategy.bufferSize
        if let newData = try await dataSource.read(maxLength: recommendedSize) {
            let written = byteBuffer.write(newData)
            if written == 0 && !newData.isEmpty {
                // Buffer is full, need to compact or resize
                byteBuffer.compact()
                byteBuffer.write(newData)
            }
        } else {
            isAtEnd = true
        }
    }

    /**
     Reads the next row from the CSV file as an array of strings.

     This method reads raw string values without any type conversion. It handles
     multi-line fields and properly processes quoted values.

     - Returns: An array of field values, or `nil` if the end of file is reached.
     - Throws: ``CSVError/encodingError`` if the file data cannot be decoded
     using the specified encoding.

     ## Example

     ```swift
     if let row = try await reader.readRow() {
     print("Name: \(row[0]), Age: \(row[1])")
     }
     ```
     */
    public func readRow() async throws -> [String]? {
        // Always use byte parser for better performance
        guard let rowBytes = try await readRowBytes() else {
            return nil
        }
        // Convert field ranges to strings
        return rowBytes.fields.map { field in
            guard field.start < field.end else { return "" }
            let fieldData = rowBytes.data[field.start..<field.end]
            var fieldString = String(data: fieldData, encoding: encoding) ?? ""

            // If the field was quoted, unescape any escaped quotes
            if field.isQuoted {
                fieldString = fieldString.replacingOccurrences(
                    of: "\(parser.escape)\(parser.quote)",
                    with: "\(parser.quote)"
                )
            }

            return fieldString
        }
    }

    /**
     Reads the next row from the CSV file as a typed value.

     This generic method reads a row and attempts to parse it into the specified
     type that conforms to ``CSVRow``. The type must be able to initialize from
     an array of string values.

     - Parameter type: The type to parse the row into.
     - Returns: A parsed value of type `T`, or `nil` if the end of file is
     reached or parsing fails.
     - Throws: ``CSVError/encodingError`` if the file data cannot be decoded
     using the specified encoding.

     ## Example

     ```swift
     struct Person: CSVRow {
     let name: String
     let age: Int
     }

     if let person = try await reader.readRow(as: Person.self) {
     print("\(person.name) is \(person.age) years old")
     }
     ```
     */
    public func readRow<T: CSVRow>(as _: T.Type) async throws -> T? {
        guard let fields = try await readRow() else {
            return nil
        }
        // Don't return nil if parsing fails - that's not EOF!
        // Let the caller handle parsing failures
        return T(from: fields)
    }

    /**
     Skips a specified number of rows in the CSV file.

     This method is useful for skipping header rows or advancing to a specific
     position in the file. Each skipped row is fully parsed to handle multi-line
     fields correctly.

     - Parameter count: The number of rows to skip.
     - Returns: The actual number of rows skipped (may be less than requested if
     EOF is reached).
     - Throws: ``CSVError/encodingError`` if the file data cannot be decoded
     using the specified encoding.

     ## Example

     ```swift
     // Skip header row
     let skipped = try await reader.skipRows(count: 1)

     // Skip multiple rows
     let skipped = try await reader.skipRows(count: 5)
     ```
     */
    @discardableResult
    public func skipRows(count: Int) async throws -> Int {
        var skipped = 0
        for _ in 0..<count {
            guard try await readRow() != nil else {
                break
            }
            skipped += 1
        }
        return skipped
    }

    /**
     Returns an async sequence for iterating over CSV rows as string arrays.

     This method provides a more idiomatic Swift way to process CSV data using
     async sequences. It supports all standard sequence operations like `map`,
     `filter`, `enumerated`, etc.

     - Returns: A ``CSVRowSequence`` that yields rows as string arrays.

     ## Example

     ```swift
     let reader = try StreamingCSVReader(url: csvFileURL)

     // Basic iteration
     for try await row in reader.rows() {
     print("Row: \(row)")
     }

     // With enumeration
     for try await (row, index) in reader.rows().enumerated() {
     print("Row \(index): \(row)")
     }

     // Filtering
     let longRows = reader.rows().filter { $0.count > 5 }
     for try await row in longRows {
     print("Long row: \(row)")
     }
     ```
     */
    public func rows() -> CSVRowSequence {
        CSVRowSequence(reader: self)
    }

    /**
     Returns an async sequence for iterating over CSV rows as typed values.

     This method provides type-safe iteration over CSV data. Each row is parsed
     into the specified type that conforms to ``CSVRow``.

     - Parameter type: The type to parse each row into.
     - Returns: A ``TypedCSVRowSequence`` that yields rows as typed values.

     ## Example

     ```swift
     @CSVRowBuilder
     struct Person {
     @Field var name: String
     @Field var age: Int
     }

     let reader = try StreamingCSVReader(url: csvFileURL)

     // Basic iteration
     for try await person in reader.rows(as: Person.self) {
     print("\(person.name) is \(person.age) years old")
     }

     // Filtering and mapping
     let adultNames = reader.rows(as: Person.self)
     .filter { $0.age >= 18 }
     .map { $0.name }

     for try await name in adultNames {
     print("Adult: \(name)")
     }
     ```
     */
    public func rows<T: CSVRow & Sendable>(as _: T.Type) -> TypedCSVRowSequence<T> {
        TypedCSVRowSequence(reader: self)
    }

    // MARK: - Deinitialization

    deinit {
        Task { @Sendable [dataSource] in
            try? await dataSource.close()
        }
    }
}
