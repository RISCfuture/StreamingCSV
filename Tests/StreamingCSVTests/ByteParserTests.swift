import Foundation
import Testing

@testable import StreamingCSV

@Suite("ByteCSVParser Tests")
struct ByteCSVParserTests {

  @Test("Parse simple unquoted row")
  func parseSimpleRow() throws {
    let parser = ByteCSVParser()
    let csvData = Data("Alice,30,New York\n".utf8)

    let (row, consumed) = try #require(parser.parseRow(from: csvData))
    #expect(row.fields.count == 3)
    #expect(row.field(at: 0) == "Alice")
    #expect(row.field(at: 1) == "30")
    #expect(row.field(at: 2) == "New York")
    #expect(consumed == csvData.count)
  }

  @Test("Parse quoted fields with commas")
  func parseQuotedFields() throws {
    let parser = ByteCSVParser()
    let csvData = Data("\"Smith, John\",30,\"New York, NY\"\n".utf8)

    let (row, _) = try #require(parser.parseRow(from: csvData))
    #expect(row.fields.count == 3)
    #expect(row.field(at: 0) == "Smith, John")
    #expect(row.field(at: 1) == "30")
    #expect(row.field(at: 2) == "New York, NY")
  }

  @Test("Parse fields with escaped quotes")
  func parseEscapedQuotes() throws {
    let parser = ByteCSVParser()
    let csvData = Data("\"She said \"\"Hello\"\"\",42,\"Test\"\n".utf8)

    let (row, _) = try #require(parser.parseRow(from: csvData))
    #expect(row.fields.count == 3)
    #expect(row.field(at: 0) == "She said \"Hello\"")
    #expect(row.field(at: 1) == "42")
    #expect(row.field(at: 2) == "Test")
  }

  @Test("Parse empty fields")
  func parseEmptyFields() throws {
    let parser = ByteCSVParser()
    let csvData = Data("Alice,,30,,\n".utf8)

    let (row, _) = try #require(parser.parseRow(from: csvData))
    #expect(row.fields.count == 5)
    #expect(row.field(at: 0) == "Alice")
    #expect(row.field(at: 1)?.isEmpty == true)
    #expect(row.field(at: 2) == "30")
    #expect(row.field(at: 3)?.isEmpty == true)
    #expect(row.field(at: 4)?.isEmpty == true)
  }

  @Test("Parse with different line endings")
  func parseLineEndings() throws {
    let parser = ByteCSVParser()

    // Test LF
    let lfData = Data("Alice,30\nBob,25".utf8)
    let lfResult = try #require(parser.parseRow(from: lfData))
    #expect(lfResult.row.field(at: 0) == "Alice")
    #expect(lfResult.consumedBytes == 9)  // "Alice,30\n"

    // Test CRLF
    let crlfData = Data("Alice,30\r\nBob,25".utf8)
    let crlfResult = try #require(parser.parseRow(from: crlfData))
    #expect(crlfResult.row.field(at: 0) == "Alice")
    #expect(crlfResult.consumedBytes == 10)  // "Alice,30\r\n"

    // Test CR
    let crData = Data("Alice,30\rBob,25".utf8)
    let crResult = try #require(parser.parseRow(from: crData))
    #expect(crResult.row.field(at: 0) == "Alice")
    #expect(crResult.consumedBytes == 9)  // "Alice,30\r"
  }

  @Test("Parse multiline quoted fields")
  func parseMultilineFields() throws {
    let parser = ByteCSVParser()
    let csvData = Data("\"Line 1\nLine 2\",42,\"Test\"\n".utf8)

    let (row, _) = try #require(parser.parseRow(from: csvData))
    #expect(row.fields.count == 3)
    #expect(row.field(at: 0) == "Line 1\nLine 2")
    #expect(row.field(at: 1) == "42")
    #expect(row.field(at: 2) == "Test")
  }

  @Test("Find row boundary")
  func findRowBoundary() throws {
    let parser = ByteCSVParser()

    // Simple case
    let simpleData = Data("Alice,30\nBob,25\n".utf8)
    let boundary1 = parser.findRowBoundary(in: simpleData)
    #expect(boundary1 == 9)  // After "Alice,30\n"

    // With quotes
    let quotedData = Data("\"Alice,30\",test\nBob,25\n".utf8)
    let boundary2 = parser.findRowBoundary(in: quotedData)
    #expect(boundary2 == 16)  // After first row

    // Starting at offset
    let boundary3 = parser.findRowBoundary(in: simpleData, startingAt: 9)
    #expect(boundary3 == simpleData.count)  // After "Bob,25\n"
  }

  @Test("Parse with custom delimiter")
  func parseCustomDelimiter() throws {
    let parser = ByteCSVParser(delimiter: ";", quote: "\"", escape: "\"")
    let csvData = Data("Alice;30;New York\n".utf8)

    let (row, _) = try #require(parser.parseRow(from: csvData))
    #expect(row.fields.count == 3)
    #expect(row.field(at: 0) == "Alice")
    #expect(row.field(at: 1) == "30")
    #expect(row.field(at: 2) == "New York")
  }

  @Test("Parse row at end of data without newline")
  func parseLastRowWithoutNewline() throws {
    let parser = ByteCSVParser()
    let csvData = Data("Alice,30,New York".utf8)

    let (row, consumed) = try #require(parser.parseRow(from: csvData))
    #expect(row.fields.count == 3)
    #expect(row.field(at: 0) == "Alice")
    #expect(row.field(at: 1) == "30")
    #expect(row.field(at: 2) == "New York")
    #expect(consumed == csvData.count)
  }

  @Test("CSVFieldRange extraction")
  func fieldRangeExtraction() throws {
    let data = Data("Hello,World".utf8)

    let field1 = CSVFieldRange(start: 0, end: 5, isQuoted: false)
    let field2 = CSVFieldRange(start: 6, end: 11, isQuoted: false)

    #expect(field1.extractString(from: data) == "Hello")
    #expect(field2.extractString(from: data) == "World")

    // Test empty field
    let emptyField = CSVFieldRange(start: 5, end: 5, isQuoted: false)
    #expect(emptyField.extractString(from: data)?.isEmpty == true)

    // Test invalid range
    let invalidField = CSVFieldRange(start: 100, end: 105, isQuoted: false)
    #expect(invalidField.extractString(from: data) == nil)
  }

  @Test("CSVRowBytes convenience methods")
  func rowBytesConvenience() throws {
    let data = Data("Alice,30,NYC".utf8)
    let fields = [
      CSVFieldRange(start: 0, end: 5, isQuoted: false),
      CSVFieldRange(start: 6, end: 8, isQuoted: false),
      CSVFieldRange(start: 9, end: 12, isQuoted: false)
    ]

    let row = CSVRowBytes(data: data, fields: fields)

    // Test field access
    #expect(row.field(at: 0) == "Alice")
    #expect(row.field(at: 1) == "30")
    #expect(row.field(at: 2) == "NYC")
    #expect(row.field(at: 3) == nil)  // Out of bounds

    // Test stringFields
    let allFields = row.stringFields
    #expect(allFields == ["Alice", "30", "NYC"])
  }
}

@Suite("CSVByteBuffer Tests")
struct CSVByteBufferTests {

  @Test("Buffer initialization")
  func bufferInit() throws {
    let buffer = CSVByteBuffer(capacity: 1024)
    #expect(buffer.isEmpty)
    #expect(buffer.readableBytes == 0)
    #expect(buffer.capacity >= 1024)
  }

  @Test("Write and read data")
  func writeAndRead() throws {
    let buffer = CSVByteBuffer()
    let testData = Data("Hello, World!".utf8)

    let written = buffer.write(testData)
    #expect(written == testData.count)
    #expect(buffer.readableBytes == testData.count)
    #expect(!buffer.isEmpty)

    let readData = try #require(buffer.read(count: 5))
    #expect(String(data: readData, encoding: .utf8) == "Hello")
    #expect(buffer.readableBytes == testData.count - 5)

    let remainingData = try #require(buffer.read(count: 100))
    #expect(String(data: remainingData, encoding: .utf8) == ", World!")
    #expect(buffer.isEmpty)
  }

  @Test("Peek without advancing")
  func peekData() throws {
    let buffer = CSVByteBuffer()
    let testData = Data("Hello".utf8)

    buffer.write(testData)

    let peeked = try #require(buffer.peek(count: 3))
    #expect(String(data: peeked, encoding: .utf8) == "Hel")
    #expect(buffer.readableBytes == 5)  // Not consumed

    let read = buffer.read(count: 3)
    #expect(String(data: read!, encoding: .utf8) == "Hel")
    #expect(buffer.readableBytes == 2)
  }

  @Test("Skip bytes")
  func skipBytes() throws {
    let buffer = CSVByteBuffer()
    let testData = Data("Hello, World!".utf8)

    buffer.write(testData)

    let skipped = buffer.skip(count: 7)
    #expect(skipped == 7)
    #expect(buffer.readableBytes == 6)

    let remaining = buffer.read(count: 10)
    #expect(String(data: remaining!, encoding: .utf8) == "World!")
  }

  @Test("Find byte in buffer")
  func findByte() throws {
    let buffer = CSVByteBuffer()
    let testData = Data("Hello, World!".utf8)

    buffer.write(testData)

    let commaIndex = buffer.findByte(UInt8(ascii: ","))
    #expect(commaIndex == 5)

    let exclamationIndex = buffer.findByte(UInt8(ascii: "!"))
    #expect(exclamationIndex == 12)

    let notFoundIndex = buffer.findByte(UInt8(ascii: "?"))
    #expect(notFoundIndex == nil)

    // Test with max length
    let limitedFind = buffer.findByte(UInt8(ascii: "!"), maxLength: 5)
    #expect(limitedFind == nil)
  }

  @Test("Find byte and read segments")
  func findByteAndRead() throws {
    let buffer = CSVByteBuffer()
    let testData = Data("field1,field2,field3".utf8)

    buffer.write(testData)

    // Find first comma and read up to it
    let comma1 = try #require(buffer.findByte(UInt8(ascii: ",")))
    let field1 = buffer.read(count: comma1)
    #expect(String(data: field1!, encoding: .utf8) == "field1")

    // Skip comma
    buffer.skip(count: 1)

    // Find next comma
    let comma2 = try #require(buffer.findByte(UInt8(ascii: ",")))
    let field2 = buffer.read(count: comma2)
    #expect(String(data: field2!, encoding: .utf8) == "field2")

    // Skip comma and read rest
    buffer.skip(count: 1)
    let field3 = buffer.read(count: 100)
    #expect(String(data: field3!, encoding: .utf8) == "field3")

    #expect(buffer.isEmpty)
  }

  @Test("Compact buffer")
  func compactBuffer() throws {
    let buffer = CSVByteBuffer(capacity: 100)
    let testData = Data("Hello, World!".utf8)

    buffer.write(testData)
    buffer.skip(count: 7)  // Skip "Hello, "

    #expect(buffer.readableBytes == 6)

    buffer.compact()

    #expect(buffer.readableBytes == 6)
    let remaining = buffer.read(count: 10)
    #expect(String(data: remaining!, encoding: .utf8) == "World!")
  }

  @Test("Clear buffer")
  func clearBuffer() throws {
    let buffer = CSVByteBuffer()
    let testData = Data("Hello, World!".utf8)

    buffer.write(testData)
    #expect(!buffer.isEmpty)

    buffer.clear()
    #expect(buffer.isEmpty)
    #expect(buffer.readableBytes == 0)
  }

  @Test("Buffer expansion on write")
  func bufferExpansion() throws {
    let buffer = CSVByteBuffer(capacity: 10)
    let largeData = Data(String(repeating: "A", count: 100).utf8)

    let written = buffer.write(largeData)
    #expect(written == 100)
    #expect(buffer.readableBytes == 100)
    #expect(buffer.capacity >= 100)
  }
}

@Suite("AdaptiveBufferStrategy Tests")
struct AdaptiveBufferStrategyTests {

  @Test("Initial buffer size")
  func initialSize() async throws {
    let strategy = AdaptiveBufferStrategy(initialSize: .medium)
    let size = await strategy.bufferSize
    #expect(size == AdaptiveBufferStrategy.BufferSize.medium.rawValue)
  }

  @Test("Buffer grows for large rows")
  func bufferGrows() async throws {
    let strategy = AdaptiveBufferStrategy(initialSize: .small)

    // Record consistently large rows (more than half the buffer size)
    // Small buffer is 16KB, so 10KB rows should trigger growth
    for _ in 0..<25 {  // Need more rows to trigger adjustment
      _ = await strategy.recordRow(size: 10000)
    }

    let finalSize = await strategy.bufferSize
    #expect(finalSize > AdaptiveBufferStrategy.BufferSize.small.rawValue)
  }

  @Test("Buffer shrinks for small rows")
  func bufferShrinks() async throws {
    let strategy = AdaptiveBufferStrategy(initialSize: .large)

    // Need enough rows to trigger decisions
    for _ in 0..<30 {
      _ = await strategy.recordRow(size: 50)
    }

    let finalSize = await strategy.bufferSize
    #expect(finalSize < AdaptiveBufferStrategy.BufferSize.large.rawValue)
  }

  @Test("Handle oversized row")
  func handleOversized() async throws {
    let strategy = AdaptiveBufferStrategy(initialSize: .small)

    let hugeRowSize = 500000
    let newSize = await strategy.handleOversizedRow(size: hugeRowSize)
    #expect(newSize >= hugeRowSize * 2)

    let currentSize = await strategy.bufferSize
    #expect(currentSize >= AdaptiveBufferStrategy.BufferSize.huge.rawValue)
  }

  @Test("Statistics tracking")
  func statistics() async throws {
    let strategy = AdaptiveBufferStrategy()

    _ = await strategy.recordRow(size: 100)
    _ = await strategy.recordRow(size: 200)
    _ = await strategy.recordRow(size: 300)

    let stats = await strategy.getStatistics()
    #expect(stats.totalRows == 3)
    #expect(stats.averageRowSize == 200)
  }

  @Test("Reset strategy")
  func resetStrategy() async throws {
    let strategy = AdaptiveBufferStrategy(initialSize: .medium)

    for _ in 0..<20 {
      _ = await strategy.recordRow(size: 1000)
    }

    await strategy.reset(toSize: .tiny)

    let stats = await strategy.getStatistics()
    #expect(stats.totalRows == 0)
    #expect(stats.currentBufferSize == AdaptiveBufferStrategy.BufferSize.tiny.rawValue)
  }

  @Test("Buffer size recommendations")
  func sizeRecommendations() throws {
    #expect(AdaptiveBufferStrategy.BufferSize.recommended(for: 25) == .tiny)
    #expect(AdaptiveBufferStrategy.BufferSize.recommended(for: 75) == .small)
    #expect(AdaptiveBufferStrategy.BufferSize.recommended(for: 500) == .medium)
    #expect(AdaptiveBufferStrategy.BufferSize.recommended(for: 2500) == .large)
    #expect(AdaptiveBufferStrategy.BufferSize.recommended(for: 10000) == .huge)
  }
}

@Suite("CSVCharacteristics Tests")
struct CSVCharacteristicsTests {

  @Test("Detect simple CSV characteristics")
  func detectSimpleCSV() throws {
    var characteristics = CSVCharacteristics()

    // Simulate observing simple rows
    let simpleRow = CSVRowBytes(
      data: Data("Alice,30,NYC".utf8),
      fields: [
        CSVFieldRange(start: 0, end: 5, isQuoted: false),
        CSVFieldRange(start: 6, end: 8, isQuoted: false),
        CSVFieldRange(start: 9, end: 12, isQuoted: false)
      ]
    )

    for _ in 0..<10 {
      characteristics.observe(rowBytes: simpleRow, rawSize: 13)
    }

    #expect(characteristics.hasQuotes == false)
    #expect(characteristics.columnCount == 3)
  }

  @Test("Detect quoted fields")
  func detectQuotedFields() throws {
    var characteristics = CSVCharacteristics()

    let quotedRow = CSVRowBytes(
      data: Data("\"Alice\",30,NYC".utf8),
      fields: [
        CSVFieldRange(start: 1, end: 6, isQuoted: true),
        CSVFieldRange(start: 8, end: 10, isQuoted: false),
        CSVFieldRange(start: 11, end: 14, isQuoted: false)
      ]
    )

    characteristics.observe(rowBytes: quotedRow, rawSize: 15)

    #expect(characteristics.hasQuotes == true)
  }

  @Test("Detect variable column counts")
  func detectVariableColumns() throws {
    var characteristics = CSVCharacteristics()

    // Rows with different column counts
    let row3cols = CSVRowBytes(
      data: Data("A,B,C".utf8),
      fields: [
        CSVFieldRange(start: 0, end: 1, isQuoted: false),
        CSVFieldRange(start: 2, end: 3, isQuoted: false),
        CSVFieldRange(start: 4, end: 5, isQuoted: false)
      ]
    )

    let row4cols = CSVRowBytes(
      data: Data("A,B,C,D".utf8),
      fields: [
        CSVFieldRange(start: 0, end: 1, isQuoted: false),
        CSVFieldRange(start: 2, end: 3, isQuoted: false),
        CSVFieldRange(start: 4, end: 5, isQuoted: false),
        CSVFieldRange(start: 6, end: 7, isQuoted: false)
      ]
    )

    // Alternate between different column counts
    for i in 0..<12 {
      if i.isMultiple(of: 2) {
        characteristics.observe(rowBytes: row3cols, rawSize: 5)
      } else {
        characteristics.observe(rowBytes: row4cols, rawSize: 7)
      }
    }

    #expect(characteristics.isFixedWidth == false)
    #expect(characteristics.columnCount == nil)
  }
}
