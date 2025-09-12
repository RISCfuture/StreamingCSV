import Foundation

/**
 A streaming CSV writer that efficiently writes large CSV files row by row.
 
 `StreamingCSVWriter` uses buffered I/O to write CSV data without keeping the
 entire file in memory, making it suitable for generating large datasets. It
 supports both raw string array writing and type-safe serialization through the
 ``CSVRow`` protocol.

 The writer is an actor, ensuring thread-safe access in concurrent environments.
 
 ## Topics

 ### Creating a Writer

 - ``init(url:delimiter:quote:escape:encoding:bufferSize:append:)``

 ### Writing Raw Data

 - ``writeRow(_:)-79v2d``

 ### Writing Typed Data

 - ``writeRow(_:)``

 ### Buffer Management

 - ``flush()``
 
 ## Example

 ```swift
 let writer = try StreamingCSVWriter(url: outputURL)
 
 // Write header
 try await writer.writeRow(["Name", "Age", "City"])
 
 // Write data rows
 try await writer.writeRow(["John", "30", "New York"])
 
 // Or write typed rows
 let person = Person(name: "Jane", age: 25, city: "Boston")
 try await writer.writeRow(person)
 
 // Ensure all data is written
 try await writer.flush()
 ```
 */
public actor StreamingCSVWriter {
    private let dataDestination: any CSVDataDestination
    private let parser: CSVParser
    private let bufferSize: Int
    private let encoding: String.Encoding
    private var buffer: Data

    /**
     Creates a new streaming CSV writer for the specified file.
     
     - Parameters:
       - url: The URL where the CSV file will be written.
       - delimiter: The character to use for separating fields. Defaults to
         comma (`,`).
       - quote: The character to use for quoting fields. Defaults to double
         quote (`"`).
       - escape: The character to use for escaping quotes. Defaults to double
         quote (`"`).
       - encoding: The string encoding to use when writing the file. Defaults to
         UTF-8.
       - bufferSize: The size of the write buffer in bytes. Defaults to 65536
         (64KB).
       - append: If `true`, appends to an existing file. If `false`, overwrites
         any existing file. Defaults to `false`.
     - Throws: An error if the file cannot be opened for writing.
     */
    public init(url: URL,
                delimiter: Character = ",",
                quote: Character = "\"",
                escape: Character = "\"",
                encoding: String.Encoding = .utf8,
                bufferSize: Int = 65536,
                append: Bool = false) throws {
        self.dataDestination = try FileDataDestination(url: url, append: append)
        self.parser = CSVParser(delimiter: delimiter, quote: quote, escape: escape)
        self.encoding = encoding
        self.bufferSize = bufferSize
        self.buffer = Data()
    }

    /**
     Creates a new streaming CSV writer with a custom data destination.
     
     This initializer allows you to provide any custom destination that
     conforms to the CSVDataDestination protocol.
     
     - Parameters:
       - destination: The data destination to write to.
       - delimiter: The character to use for separating fields. Defaults to comma (`,`).
       - quote: The character to use for quoting fields. Defaults to double quote (`"`).
       - escape: The character to use for escaping quotes. Defaults to double quote (`"`).
       - encoding: The string encoding to use when writing. Defaults to UTF-8.
       - bufferSize: The size of the write buffer in bytes. Defaults to 65536 (64KB).
     */
    public init(
        destination: any CSVDataDestination,
        delimiter: Character = ",",
        quote: Character = "\"",
        escape: Character = "\"",
        encoding: String.Encoding = .utf8,
        bufferSize: Int = 65536
    ) {
        self.dataDestination = destination
        self.parser = CSVParser(delimiter: delimiter, quote: quote, escape: escape)
        self.encoding = encoding
        self.bufferSize = bufferSize
        self.buffer = Data()
    }

    /**
     Creates a new streaming CSV writer that writes to an in-memory buffer.

     This initializer creates a writer that accumulates CSV data in memory.
     You can retrieve the data using the destination's getData() method.

     - Parameters:
     - delimiter: The character to use for separating fields. Defaults to comma (`,`).
     - quote: The character to use for quoting fields. Defaults to double quote (`"`).
     - escape: The character to use for escaping quotes. Defaults to double quote (`"`).
     - encoding: The string encoding to use when writing the data. Defaults to UTF-8.
     - bufferSize: The size of the write buffer in bytes. Defaults to 65536 (64KB).
     - Returns: A tuple containing the writer and its data destination.
     */
    public static func inMemory(
        delimiter: Character = ",",
        quote: Character = "\"",
        escape: Character = "\"",
        encoding: String.Encoding = .utf8,
        bufferSize: Int = 65536
    ) -> (writer: StreamingCSVWriter, destination: DataDataDestination) {
        let destination = DataDataDestination()
        let writer = StreamingCSVWriter(
            destination: destination,
            delimiter: delimiter,
            quote: quote,
            escape: escape,
            encoding: encoding,
            bufferSize: bufferSize
        )
        return (writer, destination)
    }

    /**
     Writes a row to the CSV file from an array of strings.
     
     The fields are automatically formatted with proper quoting and escaping as
     needed. The row is buffered and will be written to disk when the buffer
     fills or when ``flush()`` is called.

     - Parameter row: An array of field values to write.
     - Throws: ``CSVError/encodingError`` if the fields cannot be encoded using
       the specified encoding.

     ## Example

     ```swift
     try await writer.writeRow(["John Doe", "30", "New York"])
     ```
     */
    public func writeRow(_ row: [String]) async throws {
        let rowString = parser.formatRow(row) + "\n"
        guard let rowData = rowString.data(using: encoding) else {
            throw CSVError.encodingError
        }

        buffer.append(rowData)

        if buffer.count >= bufferSize {
            try await flush()
        }
    }

    /**
     Writes a typed row to the CSV file.
     
     This generic method accepts any type that conforms to ``CSVEncodableRow`` and
     converts it to CSV format. The type must be able to serialize itself to an
     array of strings.

     - Parameter row: The row value to write.
     - Throws: ``CSVError/encodingError`` if the row cannot be encoded using the
       specified encoding.

     ## Example

     ```swift
     @CSVRowEncoderBuilder
     struct Person {
         @Field var name: String
         @Field var age: Int
     }
     
     let person = Person(name: "Jane", age: 25)
     try await writer.writeRow(person)
     ```
     */
    public func writeRow<T: CSVEncodableRow>(_ row: T) async throws {
        try await writeRow(row.toCSVRow())
    }

    /**
     Flushes any buffered data to disk.
     
     Call this method to ensure all written rows are saved to the file. This is
     automatically called when the writer is deinitialized, but you may want to
     call it explicitly to ensure data is written at specific points.
     
     - Throws: An error if the flush operation fails.
     
     ## Example
     ```swift
     try await writer.writeRow(["Important", "Data"])
     try await writer.flush()  // Ensure it's written immediately
     ```
     */
    public func flush() async throws {
        if !buffer.isEmpty {
            try await dataDestination.write(buffer)
            buffer = Data()
        }
        try await dataDestination.flush()
    }

    deinit {
        Task { @Sendable [buffer, dataDestination] in
            if !buffer.isEmpty {
                try? await dataDestination.write(buffer)
            }
            try? await dataDestination.close()
        }
    }
}
