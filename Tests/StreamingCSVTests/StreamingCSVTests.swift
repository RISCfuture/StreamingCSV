import Foundation
import Testing

@testable import StreamingCSV

@Suite("CSV Parser Tests")
struct CSVParserTests {

  @Test
  func testSimpleParsing() {
    let parser = CSVParser()
    let row = parser.parseRow(from: "John,30,New York")
    #expect(row == ["John", "30", "New York"])
  }

  @Test
  func testQuotedFields() {
    let parser = CSVParser()
    let row = parser.parseRow(from: "\"John, Jr.\",30,\"New York\"")
    #expect(row == ["John, Jr.", "30", "New York"])
  }

  @Test
  func testEscapedQuotes() {
    let parser = CSVParser()
    let row = parser.parseRow(from: "\"She said \"\"Hello\"\"\",30,City")
    #expect(row == ["She said \"Hello\"", "30", "City"])
  }

  @Test
  func testEmptyFields() {
    let parser = CSVParser()
    let row = parser.parseRow(from: "John,,Doe")
    #expect(row == ["John", "", "Doe"])
  }

  @Test
  func testCustomDelimiter() {
    let parser = CSVParser(delimiter: ";")
    let row = parser.parseRow(from: "John;30;New York")
    #expect(row == ["John", "30", "New York"])
  }

  @Test
  func testFormatField() {
    let parser = CSVParser()
    #expect(parser.formatField("Simple") == "Simple")
    #expect(parser.formatField("With,Comma") == "\"With,Comma\"")
    #expect(parser.formatField("With\"Quote") == "\"With\"\"Quote\"")
    #expect(parser.formatField("With\nNewline") == "\"With\nNewline\"")
  }

  @Test
  func testFormatRow() {
    let parser = CSVParser()
    let formatted = parser.formatRow(["John", "30", "New York, NY"])
    #expect(formatted == "John,30,\"New York, NY\"")
  }
}

@Suite("StreamingCSVReader Tests", .serialized)
struct StreamingCSVReaderTests {

  func fixtureURL(_ name: String) -> URL {
    Bundle.module.url(forResource: "Fixtures/\(name)", withExtension: nil)!
  }

  @Test
  func testReadRawSimpleCSV() async throws {
    let url = fixtureURL("simple.csv")
    let reader = try StreamingCSVReader(url: url)

    // Skip header row
    _ = try await reader.readRow()

    let row1 = try await reader.readRow()
    #expect(row1 == ["John Doe", "30", "New York"])

    let row2 = try await reader.readRow()
    #expect(row2 == ["Jane Smith", "25", "Los Angeles"])

    let row3 = try await reader.readRow()
    #expect(row3 == ["Bob Johnson", "35", "Chicago"])

    let row4 = try await reader.readRow()
    #expect(row4 == nil)
  }

  @Test
  func testSkipRows() async throws {
    let url = fixtureURL("simple.csv")
    let reader = try StreamingCSVReader(url: url)

    // Skip header row
    let skipped = try await reader.skipRows(count: 1)
    #expect(skipped == 1)

    let row1 = try await reader.readRow()
    #expect(row1 == ["John Doe", "30", "New York"])

    // Skip next two rows
    let skipped2 = try await reader.skipRows(count: 2)
    #expect(skipped2 == 2)

    // Should be at end of file
    let row4 = try await reader.readRow()
    #expect(row4 == nil)
  }

  @Test
  func testSkipRowsBeyondEOF() async throws {
    let url = fixtureURL("simple.csv")
    let reader = try StreamingCSVReader(url: url)

    // Try to skip more rows than exist (file has 4 rows total)
    let skipped = try await reader.skipRows(count: 10)
    #expect(skipped == 4)

    // Should be at end of file
    let row = try await reader.readRow()
    #expect(row == nil)
  }

  @Test
  func testReadRawQuotedCSV() async throws {
    let url = fixtureURL("quoted.csv")
    let reader = try StreamingCSVReader(url: url)

    // Skip header
    _ = try await reader.readRow()

    let row1 = try await reader.readRow()
    #expect(row1 == ["Laptop", "High-performance, 16GB RAM", "1299.99"])

    let row2 = try await reader.readRow()
    #expect(row2 == ["Phone, Smart", "Latest model with 5G", "899.99"])

    let row3 = try await reader.readRow()
    #expect(row3 == ["Tablet", "10\" screen with stylus", "599.99"])
  }

  @Test
  func testReadRawMultilineCSV() async throws {
    let url = fixtureURL("multiline.csv")
    let reader = try StreamingCSVReader(url: url)

    // Skip header
    _ = try await reader.readRow()

    let row1 = try #require(await reader.readRow())
    #expect(row1.count == 3)
    #expect(row1[0] == "Project Alpha")
    #expect(row1[1].contains("multi-line") == true)
    #expect(row1[2] == "5")
  }

  @Test
  func testReadRawEmptyFields() async throws {
    let url = fixtureURL("empty_fields.csv")
    let reader = try StreamingCSVReader(url: url)

    // Skip header
    _ = try await reader.readRow()

    let row1 = try await reader.readRow()
    #expect(row1 == ["John", "", "Doe"])

    let row2 = try await reader.readRow()
    #expect(row2 == ["", "Marie", "Smith"])

    let row3 = try await reader.readRow()
    #expect(row3 == ["Alice", "Beth", ""])
  }
}

@Suite("StreamingCSVWriter Tests")
struct StreamingCSVWriterTests {

  @Test
  func testWriteRawSimpleCSV() async throws {
    let tempURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("csv")

    let writer = try StreamingCSVWriter(url: tempURL)

    try await writer.writeRow(["Name", "Age", "City"])
    try await writer.writeRow(["John Doe", "30", "New York"])
    try await writer.writeRow(["Jane Smith", "25", "Los Angeles"])
    try await writer.flush()

    let content = try String(contentsOf: tempURL, encoding: .utf8)
    #expect(content.contains("Name,Age,City"))
    #expect(content.contains("John Doe,30,New York"))

    try FileManager.default.removeItem(at: tempURL)
  }

  @Test
  func testWriteRawQuotedFields() async throws {
    let tempURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("csv")

    let writer = try StreamingCSVWriter(url: tempURL)

    try await writer.writeRow(["Product", "Description", "Price"])
    try await writer.writeRow(["Laptop", "High-performance, 16GB RAM", "1299.99"])
    try await writer.writeRow(["Phone, Smart", "Latest model with 5G", "899.99"])
    try await writer.flush()

    let content = try String(contentsOf: tempURL, encoding: .utf8)
    #expect(content.contains("\"High-performance, 16GB RAM\""))
    #expect(content.contains("\"Phone, Smart\""))

    try FileManager.default.removeItem(at: tempURL)
  }

  #if !os(Linux)
    @Test
    func testDifferentEncodings() async throws {
      let tempURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("csv")

      // Test with ISO Latin-1 encoding
      let writer = try StreamingCSVWriter(url: tempURL, encoding: .isoLatin1)
      try await writer.writeRow(["Name", "Value"])
      try await writer.writeRow(["Test", "123"])
      try await writer.writeRow(["Café", "Naïve"])
      try await writer.flush()

      // Read back with ISO Latin-1 encoding
      let reader = try StreamingCSVReader(url: tempURL, encoding: .isoLatin1)

      let header = try await reader.readRow()
      #expect(header == ["Name", "Value"])

      let row1 = try await reader.readRow()
      #expect(row1 == ["Test", "123"])

      let row2 = try await reader.readRow()
      #expect(row2 == ["Café", "Naïve"])

      try FileManager.default.removeItem(at: tempURL)
    }
  #endif

  @Test
  func testAppendMode() async throws {
    let tempURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("csv")

    let writer1 = try StreamingCSVWriter(url: tempURL)
    try await writer1.writeRow(["First", "Row"])
    try await writer1.flush()

    let writer2 = try StreamingCSVWriter(url: tempURL, append: true)
    try await writer2.writeRow(["Second", "Row"])
    try await writer2.flush()

    let content = try String(contentsOf: tempURL, encoding: .utf8)
    #expect(content.contains("First,Row"))
    #expect(content.contains("Second,Row"))

    try FileManager.default.removeItem(at: tempURL)
  }
}

@Suite("Protocol Conformance Tests")
struct ProtocolConformanceTests {

  @Test
  func testStringConformance() {
    let original = "Hello World"
    let csv = original.csvString
    let decoded = String(csvString: csv)
    #expect(decoded == original)
  }

  @Test
  func testIntConformance() {
    let original = 42
    let csv = original.csvString
    let decoded = Int(csvString: csv)
    #expect(decoded == original)

    #expect(Int(csvString: " 42 ") == 42)
    #expect(Int(csvString: "abc") == nil)
  }

  @Test
  func testDoubleConformance() {
    let original = 3.14159
    let csv = original.csvString
    let decoded = Double(csvString: csv)
    #expect(decoded == original)
  }

  @Test
  func testBoolConformance() {
    #expect(Bool(csvString: "true") == true)
    #expect(Bool(csvString: "false") == false)
    #expect(Bool(csvString: "yes") == true)
    #expect(Bool(csvString: "no") == false)
    #expect(Bool(csvString: "1") == true)
    #expect(Bool(csvString: "0") == false)
    #expect(Bool(csvString: "invalid") == nil)

    #expect(true.csvString == "true")
    #expect(false.csvString == "false")
  }

  @Test
  func testDataConformance() {
    let original = Data("Hello World".utf8)
    let csv = original.csvString
    let decoded = Data(csvString: csv)
    #expect(decoded == original)
  }

  @Test
  func testOptionalConformance() {
    let some: Int? = 42
    let none: Int? = nil

    #expect(some.csvString == "42")
    #expect(none.csvString.isEmpty)

    #expect(Int?(csvString: "42") == 42)
    let emptyOpt = Int?(csvString: "")
    #expect(emptyOpt == Optional<Int>.none)
  }
}

@Suite("AsyncSequence Tests", .serialized)
struct AsyncSequenceTests {

  func fixtureURL(_ name: String) -> URL {
    Bundle.module.url(forResource: "Fixtures/\(name)", withExtension: nil)!
  }

  @Test
  func testAsyncSequenceBasicIteration() async throws {
    let url = fixtureURL("simple.csv")
    let reader = try StreamingCSVReader(url: url)

    var rows: [[String]] = []
    for try await row in await reader.rows() {
      rows.append(row)
    }

    #expect(rows.count == 4)
    #expect(rows[0] == ["Name", "Age", "City"])
    #expect(rows[1] == ["John Doe", "30", "New York"])
    #expect(rows[2] == ["Jane Smith", "25", "Los Angeles"])
    #expect(rows[3] == ["Bob Johnson", "35", "Chicago"])
  }

  @Test
  func testAsyncSequenceEnumerated() async throws {
    let url = fixtureURL("simple.csv")
    let reader = try StreamingCSVReader(url: url)

    var indexedRows: [(Int, [String])] = []
    var index = 0
    for try await row in await reader.rows() {
      indexedRows.append((index, row))
      index += 1
    }

    #expect(indexedRows.count == 4)
    #expect(indexedRows[0].0 == 0)
    #expect(indexedRows[0].1 == ["Name", "Age", "City"])
    #expect(indexedRows[3].0 == 3)
    #expect(indexedRows[3].1 == ["Bob Johnson", "35", "Chicago"])
  }

  @Test
  func testAsyncSequenceFilter() async throws {
    let url = fixtureURL("simple.csv")
    let reader = try StreamingCSVReader(url: url)

    // Skip header
    try await reader.skipRows(count: 1)

    // Filter rows where age > 30
    let filteredRows = await reader.rows()
      .filter { row in
        guard row.count > 1,
          let age = Int(row[1])
        else { return false }
        return age > 30
      }

    var results: [[String]] = []
    for try await row in filteredRows {
      results.append(row)
    }

    #expect(results.count == 1)
    #expect(results[0] == ["Bob Johnson", "35", "Chicago"])
  }

  @Test
  func testAsyncSequencePrefix() async throws {
    let url = fixtureURL("simple.csv")
    let reader = try StreamingCSVReader(url: url)

    // Get first 2 rows
    let firstTwo = await reader.rows().prefix(2)

    var rows: [[String]] = []
    for try await row in firstTwo {
      rows.append(row)
    }

    #expect(rows.count == 2)
    #expect(rows[0] == ["Name", "Age", "City"])
    #expect(rows[1] == ["John Doe", "30", "New York"])
  }

  @Test
  func testAsyncSequenceDropFirst() async throws {
    let url = fixtureURL("simple.csv")
    let reader = try StreamingCSVReader(url: url)

    // Skip header using dropFirst
    let dataRows = await reader.rows().dropFirst()

    var rows: [[String]] = []
    for try await row in dataRows {
      rows.append(row)
    }

    #expect(rows.count == 3)
    #expect(rows[0] == ["John Doe", "30", "New York"])
    #expect(rows[2] == ["Bob Johnson", "35", "Chicago"])
  }

  @Test
  func testAsyncSequenceTyped() async throws {
    // Create a simple Product struct for testing
    struct SimpleProduct: CSVRow, Sendable {
      let id: Int
      let name: String
      let price: Double

      init?(from fields: [String]) {
        guard fields.count >= 3,
          let id = Int(fields[0]),
          let price = Double(fields[2])
        else { return nil }
        self.id = id
        self.name = fields[1]
        self.price = price
      }

      func toCSVRow() -> [String] {
        [String(id), name, String(price)]
      }
    }

    let url = fixtureURL("products.csv")
    let reader = try StreamingCSVReader(url: url)

    // Skip header
    try await reader.skipRows(count: 1)

    var products: [SimpleProduct] = []
    for try await product in await reader.rows(as: SimpleProduct.self) {
      products.append(product)
    }

    #expect(products.count == 3)
    #expect(products[0].id == 1)
    #expect(products[0].name == "Laptop")
    #expect(products[0].price == 999.99)
  }

  @Test
  func testAsyncSequenceTypedWithFilterAndMap() async throws {
    // Create a simple Product struct for testing
    struct SimpleProduct: CSVRow, Sendable {
      let id: Int
      let name: String
      let price: Double

      init?(from fields: [String]) {
        guard fields.count >= 3,
          let id = Int(fields[0]),
          let price = Double(fields[2])
        else { return nil }
        self.id = id
        self.name = fields[1]
        self.price = price
      }

      func toCSVRow() -> [String] {
        [String(id), name, String(price)]
      }
    }

    let url = fixtureURL("products.csv")
    let reader = try StreamingCSVReader(url: url)

    // Skip header
    try await reader.skipRows(count: 1)

    // Get names of products over $500
    let expensiveProductNames = await reader.rows(as: SimpleProduct.self)
      .filter { $0.price > 500 }
      .map(\.name)

    var names: [String] = []
    for try await name in expensiveProductNames {
      names.append(name)
    }

    #expect(names.count == 2)
    #expect(names.contains("Laptop"))
    #expect(names.contains("Monitor"))
    #expect(!names.contains("Keyboard"))
  }
}
