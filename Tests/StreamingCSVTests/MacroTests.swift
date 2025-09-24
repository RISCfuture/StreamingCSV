import Foundation
import Testing

@testable import StreamingCSV

// Test structs for decoder-only macro
@CSVRowDecoderBuilder
struct DecoderOnlyPerson {
  @Field var name: String
  @Field var age: Int
  @Field var city: String?
}

// Test structs for encoder-only macro
@CSVRowEncoderBuilder
struct EncoderOnlyReport {
  @Field var timestamp: String
  @Field var status: String
  @Field var value: Double
}

// Test struct with arrays for decoder
@CSVRowDecoderBuilder
struct DecoderWithArrays {
  @Field var id: String
  @Fields(3)
  var scores: [Int]
  @Fields var tags: [String]
}

// Test struct with arrays for encoder
@CSVRowEncoderBuilder
struct EncoderWithArrays {
  @Field var id: String
  @Fields(3)
  var scores: [Int]
  @Fields var tags: [String]
}

@CSVRowBuilder
struct Person {
  @Field var name: String
  @Field var age: Int
  @Field var score: Double

  // swiftlint:disable:next unneeded_synthesized_initializer
  init(name: String, age: Int, score: Double) {
    self.name = name
    self.age = age
    self.score = score
  }
}

@CSVRowBuilder
struct Product {
  @Field var id: Int
  @Field var name: String
  @Field var price: Double
  @Field var inStock: Bool
  @Field var notes: String?

  init(id: Int, name: String, price: Double, inStock: Bool, notes: String? = nil) {
    self.id = id
    self.name = name
    self.price = price
    self.inStock = inStock
    self.notes = notes
  }
}

// Test structs for @Fields functionality
@CSVRowBuilder
struct ScoreRecord {
  @Field var id: String
  @Field var name: String
  @Fields(3)
  var scores: [Int]
  @Field var grade: String
}

@CSVRowBuilder
struct FlexibleRecord {
  @Field var id: String
  @Field var name: String
  @Fields var tags: [String]
}

@CSVRowBuilder
struct ComplexRecord {
  @Field var id: String
  @Field var name: String
  @Fields(2)
  var primaryScores: [Int]
  @Fields var additionalData: [String]
}

@CSVRowBuilder
struct OptionalFieldsRecord {
  @Field var id: String
  @Fields(3)
  var values: [Double]
  @Field var status: Bool
}

@Suite("CSV Macro Tests")
struct CSVMacroTests {

  @Test
  func testPersonStruct() throws {
    // Test encoding
    let person = Person(name: "Alice", age: 25, score: 95.5)
    let row = person.toCSVRow()
    #expect(row == ["Alice", "25", "95.5"])

    // Test decoding
    let decoded = try #require(Person(from: ["Bob", "30", "87.3"]))
    #expect(decoded.name == "Bob")
    #expect(decoded.age == 30)
    #expect(decoded.score == 87.3)

    // Test invalid decoding
    let invalid = Person(from: ["Charlie", "not-a-number", "91.0"])
    #expect(invalid == nil)
  }

  @Test
  func testProductWithOptional() throws {
    // Test with optional present
    let product1 = Product(
      id: 1,
      name: "Laptop",
      price: 999.99,
      inStock: true,
      notes: "Premium model"
    )
    let row1 = product1.toCSVRow()
    #expect(row1 == ["1", "Laptop", "999.99", "true", "Premium model"])

    // Test with optional absent
    let product2 = Product(id: 2, name: "Mouse", price: 25.50, inStock: false, notes: nil)
    let row2 = product2.toCSVRow()
    #expect(row2 == ["2", "Mouse", "25.5", "false", ""])

    // Test decoding with optional
    let decoded1 = try #require(Product(from: ["3", "Keyboard", "75.0", "true", "Mechanical"]))
    #expect(decoded1.notes == "Mechanical")

    // Test decoding without optional
    let decoded2 = try #require(Product(from: ["4", "Monitor", "299.99", "false", ""]))
    #expect(decoded2.notes == nil)
  }

  @Test
  func testReadRowParsed() async throws {
    // Create a test CSV file
    let tempURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("csv")

    let csvContent = """
      Alice,25,95.5
      Bob,30,87.3
      Charlie,22,91.0
      """
    try csvContent.write(to: tempURL, atomically: true, encoding: .utf8)

    // Read with StreamingCSVReader using parsed rows
    let reader = try StreamingCSVReader(url: tempURL)

    let person1 = try await reader.readRow(as: Person.self)
    #expect(person1?.name == "Alice")
    #expect(person1?.age == 25)
    #expect(person1?.score == 95.5)

    let person2 = try await reader.readRow(as: Person.self)
    #expect(person2?.name == "Bob")
    #expect(person2?.age == 30)

    let person3 = try await reader.readRow(as: Person.self)
    #expect(person3?.score == 91.0)

    let person4 = try await reader.readRow(as: Person.self)
    #expect(person4 == nil)

    try FileManager.default.removeItem(at: tempURL)
  }

  @Test
  func testWriteRowParsed() async throws {
    let tempURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("csv")

    let people = [
      Person(name: "Alice", age: 25, score: 95.5),
      Person(name: "Bob", age: 30, score: 87.3),
      Person(name: "Charlie", age: 22, score: 91.0)
    ]

    // Write with StreamingCSVWriter using parsed rows
    let writer = try StreamingCSVWriter(url: tempURL)

    for person in people {
      try await writer.writeRow(person)
    }
    try await writer.flush()

    // Verify content
    let content = try String(contentsOf: tempURL, encoding: .utf8)
    #expect(content.contains("Alice,25,95.5"))
    #expect(content.contains("Bob,30,87.3"))
    #expect(content.contains("Charlie,22,91.0"))

    try FileManager.default.removeItem(at: tempURL)
  }

  @Test
  func testFieldsWithFixedCount() throws {
    // Test parsing with all fields present
    let record1 = try #require(ScoreRecord(from: ["001", "Alice", "85", "90", "88", "A"]))
    #expect(record1.id == "001")
    #expect(record1.name == "Alice")
    #expect(record1.scores.count == 3)
    #expect(record1.scores == [85, 90, 88])
    #expect(record1.grade == "A")

    // Test parsing with fewer scores than expected
    let record2 = try #require(ScoreRecord(from: ["002", "Bob", "95", "", "", "B"]))
    #expect(record2.scores.count == 1)  // Only one valid score
    #expect(record2.scores == [95])
    #expect(record2.grade == "B")

    // Test serialization with padding
    let row = record2.toCSVRow()
    #expect(row == ["002", "Bob", "95", "", "", "B"])  // Padded to 3 score fields

    // Test with all empty scores
    let record3 = try #require(ScoreRecord(from: ["003", "Charlie", "", "", "", "C"]))
    #expect(record3.scores.isEmpty)
    #expect(record3.grade == "C")
  }

  @Test
  func testFieldsWithRemainingFields() throws {
    // Test with no extra fields
    let record1 = try #require(FlexibleRecord(from: ["001", "Item1"]))
    #expect(record1.tags.isEmpty)

    // Test with some extra fields
    let record2 = try #require(FlexibleRecord(from: ["002", "Item2", "tag1", "tag2", "tag3"]))
    #expect(record2.tags == ["tag1", "tag2", "tag3"])

    // Test serialization (no padding for parameterless @Fields)
    let row = record2.toCSVRow()
    #expect(row == ["002", "Item2", "tag1", "tag2", "tag3"])
  }

  @Test
  func testFieldsCombined() throws {
    // Test parsing
    let record = try #require(
      ComplexRecord(from: ["001", "Test", "100", "95", "extra1", "extra2", "extra3"])
    )
    #expect(record.primaryScores == [100, 95])
    #expect(record.additionalData == ["extra1", "extra2", "extra3"])

    // Test serialization with padding for @Fields(2)
    let row = record.toCSVRow()
    #expect(row == ["001", "Test", "100", "95", "extra1", "extra2", "extra3"])

    // Test with missing primary scores
    let record2 = try #require(ComplexRecord(from: ["002", "Test2", "80", "", "data1"]))
    #expect(record2.primaryScores == [80])
    #expect(record2.additionalData == ["data1"])

    let row2 = record2.toCSVRow()
    #expect(row2 == ["002", "Test2", "80", "", "data1"])  // Padded primary scores
  }

  @Test
  func testFieldsWithOptionalTypes() throws {
    let record = try #require(OptionalFieldsRecord(from: ["001", "1.5", "2.5", "3.5", "true"]))
    #expect(record.values == [1.5, 2.5, 3.5])
    #expect(record.status == true)

    // Test with invalid numbers (should skip)
    let record2 = try #require(
      OptionalFieldsRecord(from: ["002", "4.5", "invalid", "5.5", "false"])
    )
    #expect(record2.values == [4.5, 5.5])  // "invalid" is skipped
    #expect(record2.status == false)
  }

  @Test
  func testMixedRawAndParsed() async throws {
    let tempURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("csv")

    // Write using both raw and parsed methods
    let writer = try StreamingCSVWriter(url: tempURL)

    // Write header as raw
    try await writer.writeRow(["Name", "Age", "Score"])

    // Write data as parsed
    let person = Person(name: "Alice", age: 25, score: 95.5)
    try await writer.writeRow(person)

    try await writer.flush()

    // Read back using both methods
    let reader = try StreamingCSVReader(url: tempURL)

    // Read header as raw
    let header = try await reader.readRow()
    #expect(header == ["Name", "Age", "Score"])

    // Read data as parsed
    let readPerson = try await reader.readRow(as: Person.self)
    #expect(readPerson?.name == "Alice")
    #expect(readPerson?.age == 25)
    #expect(readPerson?.score == 95.5)

    try FileManager.default.removeItem(at: tempURL)
  }

  // MARK: - Tests for new decoder/encoder-only macros

  @Test
  func testDecoderOnlyMacro() throws {
    // Test valid input
    let fields = ["Alice", "30", "New York"]
    let person = try #require(DecoderOnlyPerson(from: fields))
    #expect(person.name == "Alice")
    #expect(person.age == 30)
    #expect(person.city == "New York")

    // Test with empty optional
    let fields2 = ["Bob", "25", ""]
    let person2 = try #require(DecoderOnlyPerson(from: fields2))
    #expect(person2.name == "Bob")
    #expect(person2.age == 25)
    #expect(person2.city == nil)

    // Test invalid input
    let fields3 = ["Charlie", "not-a-number", "London"]
    let person3 = DecoderOnlyPerson(from: fields3)
    #expect(person3 == nil)

    // Test insufficient fields
    let fields4 = ["Dave"]
    let person4 = DecoderOnlyPerson(from: fields4)
    #expect(person4 == nil)
  }

  @Test
  func testEncoderOnlyMacro() throws {
    let report = EncoderOnlyReport(
      timestamp: "2024-01-15T10:30:00",
      status: "OK",
      value: 42.5
    )

    let row = report.toCSVRow()
    #expect(row == ["2024-01-15T10:30:00", "OK", "42.5"])
  }

  @Test
  func testDecoderWithArrays() throws {
    // Test with all fields populated
    let fields = ["001", "85", "90", "88", "tag1", "tag2", "tag3"]
    let record = try #require(DecoderWithArrays(from: fields))
    #expect(record.id == "001")
    #expect(record.scores == [85, 90, 88])
    #expect(record.tags == ["tag1", "tag2", "tag3"])

    // Test with partial scores
    let fields2 = ["002", "75", "", "80", "tagA"]
    let record2 = try #require(DecoderWithArrays(from: fields2))
    #expect(record2.id == "002")
    #expect(record2.scores == [75, 80])  // Empty field skipped
    #expect(record2.tags == ["tagA"])

    // Test with no tags
    let fields3 = ["003", "100", "95", "98"]
    let record3 = try #require(DecoderWithArrays(from: fields3))
    #expect(record3.id == "003")
    #expect(record3.scores == [100, 95, 98])
    #expect(record3.tags.isEmpty == true)
  }

  @Test
  func testEncoderWithArrays() throws {
    // Test with full arrays
    let record = EncoderWithArrays(
      id: "001",
      scores: [85, 90, 88],
      tags: ["tag1", "tag2", "tag3"]
    )

    let row = record.toCSVRow()
    #expect(row == ["001", "85", "90", "88", "tag1", "tag2", "tag3"])

    // Test with partial scores (should pad)
    let record2 = EncoderWithArrays(
      id: "002",
      scores: [75],
      tags: ["tagA"]
    )

    let row2 = record2.toCSVRow()
    #expect(row2 == ["002", "75", "", "", "tagA"])

    // Test with empty arrays
    let record3 = EncoderWithArrays(
      id: "003",
      scores: [],
      tags: []
    )

    let row3 = record3.toCSVRow()
    #expect(row3 == ["003", "", "", ""])  // 3 empty fields for scores, none for tags
  }

  @Test
  func testProtocolConformance() throws {
    // DecoderOnlyPerson should conform to CSVDecodableRow
    let _: CSVDecodableRow.Type = DecoderOnlyPerson.self

    // EncoderOnlyReport should conform to CSVEncodableRow
    let _: CSVEncodableRow.Type = EncoderOnlyReport.self

    // Person should conform to CSVRow (and thus both protocols)
    let _: CSVRow.Type = Person.self
    let _: CSVDecodableRow.Type = Person.self
    let _: CSVEncodableRow.Type = Person.self
  }
}
