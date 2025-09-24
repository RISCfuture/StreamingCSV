import Foundation
import Testing

@testable import StreamingCSV

/// Tests for the buffer boundary bug fix
///
/// This test suite verifies that StreamingCSV correctly handles CSV rows
/// that span buffer boundaries. Previously, the ByteCSVParser would incorrectly
/// return incomplete rows when data ended at a buffer boundary, causing data loss.
@Suite("Buffer Boundary Handling")
struct BufferBoundaryTests {

  /// Test that rows spanning buffer boundaries are parsed correctly
  ///
  /// This test creates a CSV where a row spans exactly across the typical 64KB buffer boundary.
  /// The bug would cause the parser to return an incomplete row with fewer fields than expected.
  @Test("Parse row spanning buffer boundary")
  func parseRowSpanningBufferBoundary() async throws {
    // Create a CSV with a row that will span the buffer boundary
    // First, create enough data to reach near the buffer size
    let padding = String(repeating: "x", count: 65530)
    let csvContent = """
      header1,header2,header3
      \(padding),field2,field3
      nextrow,data2,data3
      """

    let testData = csvContent.data(using: .utf8)!

    // Test with default buffer size (65536 bytes)
    let reader = StreamingCSVReader(data: testData, bufferSize: 65536)

    var rows: [[String]] = []
    while let row = try await reader.readRow() {
      rows.append(row)
    }

    #expect(rows.count == 3, "Should parse all 3 rows")
    #expect(rows[0] == ["header1", "header2", "header3"])
    #expect(rows[1].count == 3, "Second row should have 3 fields")
    #expect(rows[1][0] == padding)
    #expect(rows[1][1] == "field2")
    #expect(rows[1][2] == "field3")
    #expect(rows[2] == ["nextrow", "data2", "data3"])
  }

  /// Test that the ByteCSVParser correctly handles incomplete data
  ///
  /// The core of the fix was ensuring ByteCSVParser returns nil for incomplete rows
  /// when not at the actual end of file, allowing the reader to fetch more data.
  @Test("ByteCSVParser returns nil for incomplete rows")
  func byteParserHandlesIncompleteData() throws {
    let csvData = Data("field1,field2,field3\nvalue1,value2,value3\n".utf8)
    let parser = ByteCSVParser()

    // Parse complete data - should work
    let fullResult = try #require(parser.parseRow(from: csvData, isEndOfFile: true))
    #expect(fullResult.row.fields.count == 3, "Should have 3 fields")

    // Parse incomplete data (cut off mid-row) with isEndOfFile = false
    // Cut at position 35, which is in the middle of "value3" in the second row
    let partialData = csvData[0..<35]  // Cut off in the middle of the second row

    // First, parse and skip the header row
    let firstRow = try #require(parser.parseRow(from: partialData, isEndOfFile: false))
    #expect(firstRow.row.fields.count == 3)

    // Now try to parse the incomplete second row
    let remainingData = partialData[firstRow.consumedBytes...]
    let partialResult = parser.parseRow(from: Data(remainingData), isEndOfFile: false)
    #expect(partialResult == nil, "Should return nil for incomplete row when not at EOF")

    // But should parse if we say it's EOF
    let partialResultEOF = try #require(
      parser.parseRow(from: Data(remainingData), isEndOfFile: true)
    )
    #expect(partialResultEOF.row.fields.count >= 2, "Should have at least 2 fields in partial row")
  }

  /// Test with multiple buffer sizes to ensure the fix works consistently
  @Test("Parse with various buffer sizes", arguments: [1024, 4096, 32768, 65536, 131072])
  func parseWithVariousBufferSizes(bufferSize: Int) async throws {
    // Create test data with a long row
    let longField = String(repeating: "data", count: 20000)
    let csvContent = """
      col1,col2,col3,col4,col5
      short,\(longField),value3,value4,value5
      row2col1,row2col2,row2col3,row2col4,row2col5
      """

    let testData = csvContent.data(using: .utf8)!
    let reader = StreamingCSVReader(data: testData, bufferSize: bufferSize)

    var rows: [[String]] = []
    while let row = try await reader.readRow() {
      rows.append(row)
    }

    #expect(rows.count == 3, "Should parse all 3 rows with buffer size \(bufferSize)")

    // Verify header
    #expect(rows[0] == ["col1", "col2", "col3", "col4", "col5"])

    // Verify long row
    #expect(rows[1].count == 5, "Long row should have 5 fields")
    #expect(rows[1][0] == "short")
    #expect(rows[1][1] == longField)
    #expect(rows[1][2] == "value3")

    // Verify last row
    #expect(rows[2] == ["row2col1", "row2col2", "row2col3", "row2col4", "row2col5"])
  }

  /// Test with quoted fields at buffer boundaries
  ///
  /// Quoted fields are particularly tricky as the parser needs to track
  /// quote state across buffer boundaries.
  @Test("Quoted field at buffer boundary")
  func quotedFieldAtBufferBoundary() async throws {
    // Create a quoted field that will span the buffer boundary
    let longQuotedValue = String(repeating: "x", count: 65520)
    let csvContent = """
      name,description
      "test","\(longQuotedValue)"
      "next","row"
      """

    let testData = csvContent.data(using: .utf8)!
    let reader = StreamingCSVReader(data: testData, bufferSize: 65536)

    var rows: [[String]] = []
    while let row = try await reader.readRow() {
      rows.append(row)
    }

    #expect(rows.count == 3)
    #expect(rows[1][0] == "test")
    #expect(rows[1][1] == longQuotedValue)
    #expect(rows[2] == ["next", "row"])
  }

  /// Regression test for the specific buffer boundary bug
  ///
  /// The original bug was discovered when parsing FAA NASR data where row 127
  /// started at byte 65,056, right at the default 65,536-byte buffer boundary.
  /// The ByteCSVParser would incorrectly return an incomplete row with 78 fields
  /// instead of the expected 90 fields.
  @Test("Row at exact buffer boundary")
  func rowAtExactBufferBoundary() async throws {
    // Create data that puts a row exactly at the buffer boundary
    // Fill most of the buffer with a long field
    let bufferSize = 65536
    let beforeBoundary = String(repeating: "x", count: bufferSize - 20)

    // This CSV will have the second row starting very close to the buffer boundary
    let csvContent = """
      header1,header2,header3
      "\(beforeBoundary)",field2,field3
      critical1,critical2,critical3
      """

    let testData = csvContent.data(using: .utf8)!
    let reader = StreamingCSVReader(data: testData, bufferSize: bufferSize)

    var rows: [[String]] = []
    while let row = try await reader.readRow() {
      rows.append(row)
    }

    #expect(rows.count == 3, "Should parse all 3 rows")
    #expect(rows[0] == ["header1", "header2", "header3"])
    #expect(rows[1].count == 3, "Second row should have 3 fields")
    #expect(rows[1][0] == beforeBoundary)
    #expect(
      rows[2] == ["critical1", "critical2", "critical3"],
      "Critical row at boundary should parse correctly"
    )
  }
}
