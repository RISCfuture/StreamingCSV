import Foundation
@testable import StreamingCSV
import Testing

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

@Suite("CSV Macro Tests")
struct CSVMacroTests {

    @Test
    func testPersonStruct() throws {
        // Test encoding
        let person = Person(name: "Alice", age: 25, score: 95.5)
        let row = person.toCSVRow()
        #expect(row == ["Alice", "25", "95.5"])

        // Test decoding
        let decoded = Person(from: ["Bob", "30", "87.3"])
        #expect(decoded != nil)
        #expect(decoded?.name == "Bob")
        #expect(decoded?.age == 30)
        #expect(decoded?.score == 87.3)

        // Test invalid decoding
        let invalid = Person(from: ["Charlie", "not-a-number", "91.0"])
        #expect(invalid == nil)
    }

    @Test
    func testProductWithOptional() throws {
        // Test with optional present
        let product1 = Product(id: 1, name: "Laptop", price: 999.99, inStock: true, notes: "Premium model")
        let row1 = product1.toCSVRow()
        #expect(row1 == ["1", "Laptop", "999.99", "true", "Premium model"])

        // Test with optional absent  
        let product2 = Product(id: 2, name: "Mouse", price: 25.50, inStock: false, notes: nil)
        let row2 = product2.toCSVRow()
        #expect(row2 == ["2", "Mouse", "25.5", "false", ""])

        // Test decoding with optional
        let decoded1 = Product(from: ["3", "Keyboard", "75.0", "true", "Mechanical"])
        #expect(decoded1?.notes == "Mechanical")

        // Test decoding without optional
        let decoded2 = Product(from: ["4", "Monitor", "299.99", "false", ""])
        #expect(decoded2?.notes == nil)
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
}
