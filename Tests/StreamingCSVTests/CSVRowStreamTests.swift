import Foundation
import Testing

@testable import StreamingCSV

/// A helper async sequence that yields Data chunks from a source Data.
struct ChunkedDataSequence: AsyncSequence, Sendable {
  typealias Element = Data

  let data: Data
  let chunkSize: Int

  init(data: Data, chunkSize: Int = 10) {
    self.data = data
    self.chunkSize = chunkSize
  }

  func makeAsyncIterator() -> AsyncIterator {
    AsyncIterator(data: data, chunkSize: chunkSize)
  }

  struct AsyncIterator: AsyncIteratorProtocol {
    let data: Data
    let chunkSize: Int
    var offset: Int = 0

    mutating func next() -> Data? {
      guard offset < data.count else { return nil }
      let end = Swift.min(offset + chunkSize, data.count)
      let chunk = data[offset..<end]
      offset = end
      return chunk
    }
  }
}

@Suite("CSVRowStream Tests")
struct CSVRowStreamTests {

  @Test
  func testBasicStreaming() async throws {
    let csvContent = """
      Name,Age,City
      Alice,30,New York
      Bob,25,Los Angeles
      Charlie,35,Chicago
      """

    let data = csvContent.data(using: .utf8)!
    let chunkedStream = ChunkedDataSequence(data: data, chunkSize: 10)
    let rowStream = CSVRowStream(source: chunkedStream)

    var rows: [[String]] = []
    for try await row in rowStream {
      rows.append(row.stringFields)
    }

    #expect(rows.count == 4)
    #expect(rows[0] == ["Name", "Age", "City"])
    #expect(rows[1] == ["Alice", "30", "New York"])
    #expect(rows[2] == ["Bob", "25", "Los Angeles"])
    #expect(rows[3] == ["Charlie", "35", "Chicago"])
  }

  @Test
  func testSingleByteChunks() async throws {
    let csvContent = "A,B\n1,2\n3,4"
    let data = csvContent.data(using: .utf8)!
    let chunkedStream = ChunkedDataSequence(data: data, chunkSize: 1)
    let rowStream = CSVRowStream(source: chunkedStream)

    var rows: [[String]] = []
    for try await row in rowStream {
      rows.append(row.stringFields)
    }

    #expect(rows.count == 3)
    #expect(rows[0] == ["A", "B"])
    #expect(rows[1] == ["1", "2"])
    #expect(rows[2] == ["3", "4"])
  }

  @Test
  func testLargeChunks() async throws {
    let csvContent = "Name,Value\nTest,123\nAnother,456"
    let data = csvContent.data(using: .utf8)!
    let chunkedStream = ChunkedDataSequence(data: data, chunkSize: 1000)
    let rowStream = CSVRowStream(source: chunkedStream)

    var rows: [[String]] = []
    for try await row in rowStream {
      rows.append(row.stringFields)
    }

    #expect(rows.count == 3)
    #expect(rows[0] == ["Name", "Value"])
    #expect(rows[1] == ["Test", "123"])
    #expect(rows[2] == ["Another", "456"])
  }

  @Test
  func testQuotedFieldsAcrossChunks() async throws {
    let csvContent = """
      Name,Description
      "Product A","A very long description that spans multiple chunks"
      "Product B","Short"
      """

    let data = csvContent.data(using: .utf8)!
    let chunkedStream = ChunkedDataSequence(data: data, chunkSize: 15)
    let rowStream = CSVRowStream(source: chunkedStream)

    var rows: [[String]] = []
    for try await row in rowStream {
      rows.append(row.stringFields)
    }

    #expect(rows.count == 3)
    #expect(rows[0] == ["Name", "Description"])
    #expect(rows[1] == ["Product A", "A very long description that spans multiple chunks"])
    #expect(rows[2] == ["Product B", "Short"])
  }

  @Test
  func testEscapedQuotes() async throws {
    // Note: CSV uses "" to escape quotes within quoted fields
    let csvContent = "Name,Quote\nAlice,\"She said \"\"Hello\"\"\"\nBob,\"A \"\"quoted\"\" word\""

    let data = csvContent.data(using: .utf8)!
    let chunkedStream = ChunkedDataSequence(data: data, chunkSize: 8)
    let rowStream = CSVRowStream(source: chunkedStream)

    var rows: [[String]] = []
    for try await row in rowStream {
      rows.append(row.stringFields)
    }

    #expect(rows.count == 3)
    #expect(rows[0] == ["Name", "Quote"])
    #expect(rows[1] == ["Alice", "She said \"Hello\""])
    #expect(rows[2] == ["Bob", "A \"quoted\" word"])
  }

  @Test
  func testMultilineQuotedFields() async throws {
    let csvContent = "Name,Address\n\"John\",\"123 Main St\nApt 4\nNew York\""

    let data = csvContent.data(using: .utf8)!
    let chunkedStream = ChunkedDataSequence(data: data, chunkSize: 12)
    let rowStream = CSVRowStream(source: chunkedStream)

    var rows: [[String]] = []
    for try await row in rowStream {
      rows.append(row.stringFields)
    }

    #expect(rows.count == 2)
    #expect(rows[0] == ["Name", "Address"])
    #expect(rows[1] == ["John", "123 Main St\nApt 4\nNew York"])
  }

  @Test
  func testEmptyFields() async throws {
    let csvContent = "A,B,C\n1,,3\n,2,\n,,"

    let data = csvContent.data(using: .utf8)!
    let chunkedStream = ChunkedDataSequence(data: data, chunkSize: 5)
    let rowStream = CSVRowStream(source: chunkedStream)

    var rows: [[String]] = []
    for try await row in rowStream {
      rows.append(row.stringFields)
    }

    #expect(rows.count == 4)
    #expect(rows[0] == ["A", "B", "C"])
    #expect(rows[1] == ["1", "", "3"])
    #expect(rows[2] == ["", "2", ""])
    #expect(rows[3] == ["", "", ""])
  }

  @Test
  func testCRLFLineEndings() async throws {
    let csvContent = "A,B\r\n1,2\r\n3,4"

    let data = csvContent.data(using: .utf8)!
    let chunkedStream = ChunkedDataSequence(data: data, chunkSize: 3)
    let rowStream = CSVRowStream(source: chunkedStream)

    var rows: [[String]] = []
    for try await row in rowStream {
      rows.append(row.stringFields)
    }

    #expect(rows.count == 3)
    #expect(rows[0] == ["A", "B"])
    #expect(rows[1] == ["1", "2"])
    #expect(rows[2] == ["3", "4"])
  }

  @Test
  func testEmptyInput() async throws {
    let data = Data()
    let chunkedStream = ChunkedDataSequence(data: data, chunkSize: 10)
    let rowStream = CSVRowStream(source: chunkedStream)

    var rows: [[String]] = []
    for try await row in rowStream {
      rows.append(row.stringFields)
    }

    #expect(rows.isEmpty)
  }

  @Test
  func testSingleRow() async throws {
    let csvContent = "A,B,C"

    let data = csvContent.data(using: .utf8)!
    let chunkedStream = ChunkedDataSequence(data: data, chunkSize: 2)
    let rowStream = CSVRowStream(source: chunkedStream)

    var rows: [[String]] = []
    for try await row in rowStream {
      rows.append(row.stringFields)
    }

    #expect(rows.count == 1)
    #expect(rows[0] == ["A", "B", "C"])
  }

  @Test
  func testCustomDelimiter() async throws {
    let csvContent = "A;B;C\n1;2;3"

    let data = csvContent.data(using: .utf8)!
    let chunkedStream = ChunkedDataSequence(data: data, chunkSize: 5)
    let rowStream = CSVRowStream(source: chunkedStream, delimiter: ";")

    var rows: [[String]] = []
    for try await row in rowStream {
      rows.append(row.stringFields)
    }

    #expect(rows.count == 2)
    #expect(rows[0] == ["A", "B", "C"])
    #expect(rows[1] == ["1", "2", "3"])
  }

  @Test
  func testLargeData() async throws {
    var csvContent = "ID,Value,Description\n"
    for i in 1...1000 {
      csvContent += "\(i),\(i * 100),\"Description for item \(i)\"\n"
    }

    let data = csvContent.data(using: .utf8)!
    let chunkedStream = ChunkedDataSequence(data: data, chunkSize: 100)
    let rowStream = CSVRowStream(source: chunkedStream)

    var count = 0
    var firstDataRow: [String]?
    var lastDataRow: [String]?

    for try await row in rowStream {
      count += 1
      if count == 2 {
        firstDataRow = row.stringFields
      }
      lastDataRow = row.stringFields
    }

    #expect(count == 1001)  // Header + 1000 data rows
    #expect(firstDataRow == ["1", "100", "Description for item 1"])
    #expect(lastDataRow == ["1000", "100000", "Description for item 1000"])
  }

  @Test
  func testFieldAtIndex() async throws {
    let csvContent = "A,B,C,D,E\n1,2,3,4,5"

    let data = csvContent.data(using: .utf8)!
    let chunkedStream = ChunkedDataSequence(data: data, chunkSize: 5)
    let rowStream = CSVRowStream(source: chunkedStream)

    var dataRow: CSVRowBytes?
    for try await row in rowStream {
      dataRow = row  // Last row will be "1,2,3,4,5"
    }

    #expect(dataRow?.field(at: 0) == "1")
    #expect(dataRow?.field(at: 2) == "3")
    #expect(dataRow?.field(at: 4) == "5")
    #expect(dataRow?.field(at: 5) == nil)  // Out of bounds
  }

  @Test
  func testConvenienceInitializer() async throws {
    let csvContent = "A,B\n1,2"
    let data = csvContent.data(using: .utf8)!
    let chunkedStream = ChunkedDataSequence(data: data, chunkSize: 10)
    let rowStream = CSVRowStream(chunkedStream)

    var rows: [[String]] = []
    for try await row in rowStream {
      rows.append(row.stringFields)
    }

    #expect(rows.count == 2)
  }
}

private struct TestPerson: CSVDecodableRow, Sendable {
  let name: String
  let age: Int
  let city: String

  init?(from fields: [String]) {
    guard fields.count >= 3,
      let age = Int(fields[1])
    else {
      return nil
    }
    self.name = fields[0]
    self.age = age
    self.city = fields[2]
  }
}

@Suite("TypedCSVRowStream Tests")
struct TypedCSVRowStreamTests {
  @Test
  func testTypedStreaming() async throws {
    // Use data rows only (no header that would fail to parse)
    let csvContent = "Alice,30,New York\nBob,25,Los Angeles\nCharlie,35,Chicago"

    let data = csvContent.data(using: .utf8)!
    let chunkedStream = ChunkedDataSequence(data: data, chunkSize: 15)
    let rowStream = TypedCSVRowStream<TestPerson, _>(source: chunkedStream)

    var people: [TestPerson] = []
    for try await person in rowStream {
      people.append(person)
    }

    #expect(people.count == 3)
    #expect(people[0].name == "Alice")
    #expect(people[0].age == 30)
    #expect(people[0].city == "New York")
    #expect(people[1].name == "Bob")
    #expect(people[2].name == "Charlie")
  }

  @Test
  func testTypedMethodOnCSVRowStream() async throws {
    // Use data rows only (no header that would fail to parse)
    let csvContent = "Alice,30,Boston\nBob,25,Seattle"

    let data = csvContent.data(using: .utf8)!
    let chunkedStream = ChunkedDataSequence(data: data, chunkSize: 10)
    let rowStream = CSVRowStream(source: chunkedStream)

    var people: [TestPerson] = []
    for try await person in rowStream.typed(as: TestPerson.self) {
      people.append(person)
    }

    #expect(people.count == 2)
    #expect(people[0].name == "Alice")
    #expect(people[1].name == "Bob")
  }

  @Test
  func testReturnsNilOnInvalidRow() async throws {
    // First row is valid, second is invalid (Age is not an Int)
    let csvContent = "Alice,30,New York\nInvalid,NotANumber,Test"

    let data = csvContent.data(using: .utf8)!
    let chunkedStream = ChunkedDataSequence(data: data, chunkSize: 12)
    let rowStream = TypedCSVRowStream<TestPerson, _>(source: chunkedStream)

    var people: [TestPerson] = []
    for try await person in rowStream {
      people.append(person)
    }

    // Should get Alice, then nil for invalid row ends iteration
    #expect(people.count == 1)
    #expect(people[0].name == "Alice")
  }
}

private struct SimpleRecord: CSVDecodableRow, Sendable {
  let id: String
  let value: String

  init?(from fields: [String]) {
    guard fields.count >= 2 else { return nil }
    self.id = fields[0]
    self.value = fields[1]
  }
}

@Suite("StreamingCSVReader Stream Factory Tests")
struct StreamingCSVReaderStreamFactoryTests {
  @Test
  func testStreamFactoryMethod() async throws {
    let csvContent = "A,B,C\n1,2,3\n4,5,6"

    let data = csvContent.data(using: .utf8)!
    let chunkedStream = ChunkedDataSequence(data: data, chunkSize: 8)
    let rowStream = StreamingCSVReader.stream(from: chunkedStream)

    var rows: [[String]] = []
    for try await row in rowStream {
      rows.append(row.stringFields)
    }

    #expect(rows.count == 3)
    #expect(rows[0] == ["A", "B", "C"])
    #expect(rows[1] == ["1", "2", "3"])
    #expect(rows[2] == ["4", "5", "6"])
  }

  @Test
  func testTypedStreamFactoryMethod() async throws {
    // Use data rows only (header would parse successfully as SimpleRecord since both fields are strings)
    let csvContent = "1,First\n2,Second\n3,Third"

    let data = csvContent.data(using: .utf8)!
    let chunkedStream = ChunkedDataSequence(data: data, chunkSize: 10)
    let rowStream = StreamingCSVReader.stream(from: chunkedStream, as: SimpleRecord.self)

    var records: [SimpleRecord] = []
    for try await record in rowStream {
      records.append(record)
    }

    #expect(records.count == 3)
    #expect(records[0].id == "1")
    #expect(records[0].value == "First")
    #expect(records[2].id == "3")
  }

  @Test
  func testStreamWithCustomDelimiter() async throws {
    let csvContent = "A|B|C\n1|2|3"

    let data = csvContent.data(using: .utf8)!
    let chunkedStream = ChunkedDataSequence(data: data, chunkSize: 5)
    let rowStream = StreamingCSVReader.stream(from: chunkedStream, delimiter: "|")

    var rows: [[String]] = []
    for try await row in rowStream {
      rows.append(row.stringFields)
    }

    #expect(rows.count == 2)
    #expect(rows[0] == ["A", "B", "C"])
    #expect(rows[1] == ["1", "2", "3"])
  }
}
