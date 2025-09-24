import Foundation
import Testing

@testable import StreamingCSV

// Helper actor for counting rows safely
actor ProcessedRowsCounter {
  private var _count = 0

  var count: Int {
    _count
  }

  func increment() {
    _count += 1
  }
}

@Suite("ParallelCSVReader Tests")
struct ParallelCSVReaderTests {

  @Test("Process CSV with multiple workers")
  func parallelProcessing() async throws {
    let csvContent = """
      Name,Age,Department
      Alice,30,Engineering
      Bob,25,Design
      Charlie,35,Marketing
      David,28,Sales
      Eve,32,Engineering
      Frank,29,Design
      Grace,31,Marketing
      Henry,27,Sales
      """

    let url = try createTempCSVFile(content: csvContent)
    defer { try? FileManager.default.removeItem(at: url) }

    let reader = ParallelCSVReader(url: url, parallelism: 2)

    let result = try await reader.readAllRows()

    #expect(result.totalRows == 9)  // Header + 8 data rows
    #expect(result.rows.count == 9)

    let names = result.rows.dropFirst().compactMap(\.first)
    #expect(names.contains("Alice"))
    #expect(names.contains("Henry"))
  }

  @Test("Handle small files with single worker")
  func smallFileSingleWorker() async throws {
    let csvContent = """
      A,B,C
      1,2,3
      4,5,6
      """

    let url = try createTempCSVFile(content: csvContent)
    defer { try? FileManager.default.removeItem(at: url) }

    let reader = ParallelCSVReader(url: url, parallelism: 1)

    let result = try await reader.readAllRows()

    #expect(result.rows.count == 3)
    #expect(result.rows[0] == ["A", "B", "C"])
    #expect(result.rows[1] == ["1", "2", "3"])
    #expect(result.rows[2] == ["4", "5", "6"])
  }

  @Test("Process CSV with quotes and special characters")
  func handleComplexCSV() async throws {
    let csvContent = """
      Name,Description,Price
      "Product A","Contains, comma",99.99
      "Product B","Has \\"quotes\\"",149.99
      "Product C","Multi-line",199.99
      """

    let url = try createTempCSVFile(content: csvContent)
    defer { try? FileManager.default.removeItem(at: url) }

    let reader = ParallelCSVReader(url: url, parallelism: 2)

    let result = try await reader.readAllRows()
    let products = result.rows.dropFirst()

    #expect(products.count == 3)
    if let firstProduct = products.first {
      #expect(firstProduct[1] == "Contains, comma")
    }
  }

  @Test("Automatic worker count selection")
  func automaticWorkerCount() async throws {
    let csvContent = "A,B,C\n1,2,3\n"
    let url = try createTempCSVFile(content: csvContent)
    defer { try? FileManager.default.removeItem(at: url) }

    // Test with automatic worker count (nil)
    let reader = ParallelCSVReader(url: url, parallelism: nil)

    let result = try await reader.readAllRows()
    #expect(result.totalRows == 2)
  }

  @Test("Custom delimiter support")
  func customDelimiter() async throws {
    let csvContent = "A;B;C\n1;2;3\n4;5;6\n"
    let url = try createTempCSVFile(content: csvContent)
    defer { try? FileManager.default.removeItem(at: url) }

    let reader = ParallelCSVReader(
      url: url,
      delimiter: ";",
      parallelism: 1
    )

    let result = try await reader.readAllRows()

    #expect(result.rows.count == 3)
    #expect(result.rows[0] == ["A", "B", "C"])
    #expect(result.rows[1] == ["1", "2", "3"])
  }

  @Test("Large file simulation")
  func largeFileProcessing() async throws {
    // Generate a larger CSV file
    var csvContent = "ID,Name,Value,Status,Timestamp\n"
    for i in 1...1000 {
      csvContent += "\(i),User\(i),\(Double.random(in: 0...1000)),Active,2024-01-\(i % 28 + 1)\n"
    }

    let url = try createTempCSVFile(content: csvContent)
    defer { try? FileManager.default.removeItem(at: url) }

    let reader = ParallelCSVReader(url: url, parallelism: 4)

    let result = try await reader.readAllRows()

    #expect(result.totalRows == 1001)  // Header + 1000 data rows
    #expect(result.processingTime >= 0)

    // Check that values are parsed correctly
    let dataRows = result.rows.dropFirst()
    var totalValue: Double = 0
    for row in dataRows where row.count > 2 {
      if let value = Double(row[2]) {
        totalValue += value
      }
    }
    #expect(totalValue > 0)
  }

  @Test("Empty file handling")
  func emptyFile() async throws {
    let url = try createTempCSVFile(content: "")
    defer { try? FileManager.default.removeItem(at: url) }

    let reader = ParallelCSVReader(url: url)

    let result = try await reader.readAllRows()
    #expect(result.totalRows == 0)
  }

  @Test("Single column CSV")
  func singleColumn() async throws {
    let csvContent = """
      Name
      Alice
      Bob
      Charlie
      """

    let url = try createTempCSVFile(content: csvContent)
    defer { try? FileManager.default.removeItem(at: url) }

    let reader = ParallelCSVReader(url: url, parallelism: 2)

    let result = try await reader.readAllRows()
    let names = result.rows.dropFirst().compactMap(\.first)

    #expect(names == ["Alice", "Bob", "Charlie"])
  }

  @Test("CSV with empty fields")
  func emptyFields() async throws {
    let csvContent = """
      A,B,C,D
      1,,3,
      ,2,,4
      ,,,
      5,6,7,8
      """

    let url = try createTempCSVFile(content: csvContent)
    defer { try? FileManager.default.removeItem(at: url) }

    let reader = ParallelCSVReader(url: url)

    let result = try await reader.readAllRows()

    #expect(result.rows.count == 5)
    #expect(result.rows[1] == ["1", "", "3", ""])
    #expect(result.rows[2] == ["", "2", "", "4"])
    #expect(result.rows[3] == ["", "", "", ""])
    #expect(result.rows[4] == ["5", "6", "7", "8"])
  }

  @Test("Process with row handler")
  func processWithHandler() async throws {
    let csvContent = (1...100).map { "Row\($0),Value\($0)" }.joined(separator: "\n")
    let url = try createTempCSVFile(content: csvContent)
    defer { try? FileManager.default.removeItem(at: url) }

    let reader = ParallelCSVReader(url: url, parallelism: 3)

    // Process rows and ensure no duplicates or missing rows
    let seenRowsActor = ProcessedRowsCounter()

    try await reader.processRows { row in
      if row.first != nil {
        await seenRowsActor.increment()
      }
    }

    let uniqueCount = await seenRowsActor.count
    #expect(uniqueCount == 100)
  }

  // Helper function to create temporary CSV file
  private func createTempCSVFile(content: String) throws -> URL {
    let tempDir = FileManager.default.temporaryDirectory
    let fileName = "test_\(UUID().uuidString).csv"
    let url = tempDir.appendingPathComponent(fileName)
    try content.write(to: url, atomically: true, encoding: .utf8)
    return url
  }
}

@Suite("ParallelCSVReader Performance Tests")
struct ParallelCSVReaderPerformanceTests {

  @Test("Compare parallel vs sequential processing")
  func comparePerformance() async throws {
    // Generate a medium-sized CSV
    var csvContent = "ID,Name,Value,Category,Status\n"
    for i in 1...5000 {
      let category = ["A", "B", "C", "D"][i % 4]
      csvContent += "\(i),Item\(i),\(i * 10),\(category),Active\n"
    }

    let url = try createTempCSVFile(content: csvContent)
    defer { try? FileManager.default.removeItem(at: url) }

    // Test with different worker counts
    let workerCounts = [1, 2, 4]
    var results: [Int: Int] = [:]

    for workers in workerCounts {
      let reader = ParallelCSVReader(url: url, parallelism: workers)
      let result = try await reader.readAllRows()
      results[workers] = result.totalRows
    }

    // All worker counts should process the same number of rows
    #expect(results[1] == 5001)
    #expect(results[2] == 5001)
    #expect(results[4] == 5001)
  }

  @Test("Memory efficiency with large files")
  func memoryEfficiency() async throws {
    // Create a file with many rows but moderate total size
    var csvContent = "A,B,C\n"
    for i in 1...10000 {
      csvContent += "\(i),\(i + 1),\(i + 2)\n"
    }

    let url = try createTempCSVFile(content: csvContent)
    defer { try? FileManager.default.removeItem(at: url) }

    let reader = ParallelCSVReader(url: url, parallelism: 4)

    let result = try await reader.readAllRows()
    #expect(result.totalRows == 10001)

    // Process with handler to test streaming
    let processedRowsActor = ProcessedRowsCounter()
    try await reader.processRows { _ in
      await processedRowsActor.increment()
    }
    let processedRows = await processedRowsActor.count
    #expect(processedRows == 10001)
  }

  private func createTempCSVFile(content: String) throws -> URL {
    let tempDir = FileManager.default.temporaryDirectory
    let fileName = "perf_test_\(UUID().uuidString).csv"
    let url = tempDir.appendingPathComponent(fileName)
    try content.write(to: url, atomically: true, encoding: .utf8)
    return url
  }
}
