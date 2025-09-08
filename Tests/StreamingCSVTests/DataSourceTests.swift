import Foundation
@testable import StreamingCSV
import Testing

@Suite("Data Source Tests")
struct DataSourceTests {

    @Test
    func testDataDataSource() async throws {
        let csvContent = """
        Name,Age,City
        Alice,30,New York
        Bob,25,Los Angeles
        Charlie,35,Chicago
        """

        let data = csvContent.data(using: .utf8)!
        let reader = StreamingCSVReader(data: data)

        let header = try await reader.readRow()
        #expect(header == ["Name", "Age", "City"])

        let row1 = try await reader.readRow()
        #expect(row1 == ["Alice", "30", "New York"])

        let row2 = try await reader.readRow()
        #expect(row2 == ["Bob", "25", "Los Angeles"])

        let row3 = try await reader.readRow()
        #expect(row3 == ["Charlie", "35", "Chicago"])

        let row4 = try await reader.readRow()
        #expect(row4 == nil)
    }

    @Test
    func testAsyncBytesDataSource() async throws {
        let csvContent = """
        ID,Name,Score
        1,Alice,95
        2,Bob,87
        3,Charlie,92
        """

        let data = csvContent.data(using: .utf8)!

        // Create an AsyncBytes sequence from the data
        struct ByteSequence: AsyncSequence {
            typealias Element = UInt8

            let data: Data

            func makeAsyncIterator() -> ByteIterator {
                ByteIterator(data: data)
            }

            struct ByteIterator: AsyncIteratorProtocol {
                let data: Data
                var index = 0

                mutating func next() -> UInt8? {
                    guard index < data.count else { return nil }
                    let byte = data[index]
                    index += 1
                    return byte
                }
            }
        }

        let byteSequence = ByteSequence(data: data)
        let reader = try await StreamingCSVReader(bytes: byteSequence)

        let header = try await reader.readRow()
        #expect(header == ["ID", "Name", "Score"])

        let row1 = try await reader.readRow()
        #expect(row1 == ["1", "Alice", "95"])

        let row2 = try await reader.readRow()
        #expect(row2 == ["2", "Bob", "87"])

        let row3 = try await reader.readRow()
        #expect(row3 == ["3", "Charlie", "92"])

        let row4 = try await reader.readRow()
        #expect(row4 == nil)
    }

    @Test
    func testLargeDataWithDataSource() async throws {
        // Generate a large CSV dataset
        var csvContent = "ID,Value,Description\n"
        for i in 1...1000 {
            csvContent += "\(i),\(i * 100),\"Description for item \(i)\"\n"
        }

        let data = csvContent.data(using: .utf8)!
        let reader = StreamingCSVReader(data: data)

        // Skip header
        _ = try await reader.readRow()

        // Read and verify first few rows
        let row1 = try await reader.readRow()
        #expect(row1 == ["1", "100", "Description for item 1"])

        let row2 = try await reader.readRow()
        #expect(row2 == ["2", "200", "Description for item 2"])

        // Count total rows
        var count = 2  // Already read 2 rows
        while try await reader.readRow() != nil {
            count += 1
        }
        #expect(count == 1000)
    }

    @Test
    func testQuotedFieldsWithDataSource() async throws {
        let csvContent = """
        Name,Description,Price
        "Laptop, Pro","High-performance, 16GB RAM",1299.99
        "Phone","Latest model with 5G",899.99
        "Tablet","10\"\" screen with stylus",599.99
        """

        let data = csvContent.data(using: .utf8)!
        let reader = StreamingCSVReader(data: data)

        // Skip header
        _ = try await reader.readRow()

        let row1 = try await reader.readRow()
        #expect(row1 == ["Laptop, Pro", "High-performance, 16GB RAM", "1299.99"])

        let row2 = try await reader.readRow()
        #expect(row2 == ["Phone", "Latest model with 5G", "899.99"])

        let row3 = try await reader.readRow()
        #expect(row3 == ["Tablet", "10\" screen with stylus", "599.99"])
    }

    @Test
    func testEmptyDataSource() async throws {
        let data = Data()
        let reader = StreamingCSVReader(data: data)

        let row = try await reader.readRow()
        #expect(row == nil)
    }

    @Test
    func testAsyncSequenceWithDataSource() async throws {
        let csvContent = """
        A,B,C
        1,2,3
        4,5,6
        """

        let data = csvContent.data(using: .utf8)!
        let reader = StreamingCSVReader(data: data)

        var rows: [[String]] = []
        for try await row in await reader.rows() {
            rows.append(row)
        }

        #expect(rows.count == 3)
        #expect(rows[0] == ["A", "B", "C"])
        #expect(rows[1] == ["1", "2", "3"])
        #expect(rows[2] == ["4", "5", "6"])
    }
}

@Suite("Data Destination Tests")
struct DataDestinationTests {

    @Test
    func testInMemoryWriter() async throws {
        let (writer, destination) = StreamingCSVWriter.inMemory()

        try await writer.writeRow(["Name", "Age", "City"])
        try await writer.writeRow(["Alice", "30", "New York"])
        try await writer.writeRow(["Bob", "25", "Los Angeles"])
        try await writer.flush()

        let data = await destination.getData()
        let content = String(data: data, encoding: .utf8)!

        #expect(content.contains("Name,Age,City"))
        #expect(content.contains("Alice,30,New York"))
        #expect(content.contains("Bob,25,Los Angeles"))
    }

    @Test
    func testRoundTripWithMemory() async throws {
        // Write to memory
        let (writer, destination) = StreamingCSVWriter.inMemory()

        try await writer.writeRow(["ID", "Product", "Price"])
        try await writer.writeRow(["1", "Laptop", "999.99"])
        try await writer.writeRow(["2", "Phone", "699.99"])
        try await writer.writeRow(["3", "Tablet", "399.99"])
        try await writer.flush()

        // Read from memory
        let data = await destination.getData()
        let reader = StreamingCSVReader(data: data)

        let header = try await reader.readRow()
        #expect(header == ["ID", "Product", "Price"])

        let row1 = try await reader.readRow()
        #expect(row1 == ["1", "Laptop", "999.99"])

        let row2 = try await reader.readRow()
        #expect(row2 == ["2", "Phone", "699.99"])

        let row3 = try await reader.readRow()
        #expect(row3 == ["3", "Tablet", "399.99"])

        let row4 = try await reader.readRow()
        #expect(row4 == nil)
    }

    @Test
    func testLargeDataWithDestination() async throws {
        let (writer, destination) = StreamingCSVWriter.inMemory()

        // Write header
        try await writer.writeRow(["ID", "Value", "Description"])

        // Write many rows
        for i in 1...100 {
            try await writer.writeRow([
                String(i),
                String(i * 100),
                "Description for item \(i)"
            ])
        }

        try await writer.flush()

        let data = await destination.getData()
        let content = String(data: data, encoding: .utf8)!

        // Verify content
        let lines = content.split(separator: "\n")
        #expect(lines.count == 101)  // Header + 100 rows
        #expect(lines[0] == "ID,Value,Description")
        #expect(lines[1] == "1,100,Description for item 1")
        #expect(lines[100] == "100,10000,Description for item 100")
    }

    @Test
    func testQuotedFieldsWithDestination() async throws {
        let (writer, destination) = StreamingCSVWriter.inMemory()

        try await writer.writeRow(["Product", "Description", "Price"])
        try await writer.writeRow(["Laptop, Pro", "High-performance, 16GB RAM", "1299.99"])
        try await writer.writeRow(["Phone", "Latest model with \"5G\"", "899.99"])
        try await writer.flush()

        let data = await destination.getData()
        let content = String(data: data, encoding: .utf8)!

        #expect(content.contains("\"Laptop, Pro\""))
        #expect(content.contains("\"High-performance, 16GB RAM\""))
        #expect(content.contains("\"Latest model with \"\"5G\"\"\""))
    }
}
