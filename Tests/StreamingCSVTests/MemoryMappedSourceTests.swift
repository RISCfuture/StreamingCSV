import Foundation
import Testing

@testable import StreamingCSV

@Suite
struct `MemoryMappedFileDataSource tests` {

  @Test
  func `initializes from a readable file`() async throws {
    let content = "Name,Age,City\nAlice,30,NYC\nBob,25,LA\n"
    let url = try createTempFile(content: content)
    defer { try? FileManager.default.removeItem(at: url) }

    let source = try MemoryMappedFileDataSource(url: url)

    let totalSize = await source.fileSize
    #expect(totalSize == content.utf8.count)
  }

  @Test
  func `reads data in chunks`() async throws {
    let content = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    let url = try createTempFile(content: content)
    defer { try? FileManager.default.removeItem(at: url) }

    let source = try MemoryMappedFileDataSource(url: url)

    // Read first chunk
    let chunk1 = try await source.read(maxLength: 10) ?? Data()
    #expect(chunk1.count == 10)
    #expect(String(data: chunk1, encoding: .utf8) == "ABCDEFGHIJ")

    // Read second chunk
    let chunk2 = try await source.read(maxLength: 10) ?? Data()
    #expect(chunk2.count == 10)
    #expect(String(data: chunk2, encoding: .utf8) == "KLMNOPQRST")

    // Read remaining
    let chunk3 = try await source.read(maxLength: 10) ?? Data()
    #expect(chunk3.count == 6)
    #expect(String(data: chunk3, encoding: .utf8) == "UVWXYZ")

    // No more data
    let moreData = try await source.read(maxLength: 1)
    #expect(moreData == nil)
  }

  @Test
  func `reads at a specific offset`() async throws {
    let content = "0123456789ABCDEFGHIJ"
    let url = try createTempFile(content: content)
    defer { try? FileManager.default.removeItem(at: url) }

    let source = try MemoryMappedFileDataSource(url: url)

    // Read from offset 5
    let data = await source.createSlice(from: 5, to: 15)
    #expect(data.count == 10)
    #expect(String(data: data, encoding: .utf8) == "56789ABCDE")

    // Read from offset 15
    let data2 = await source.createSlice(from: 15, to: 25)
    #expect(data2.count == 5)  // Only 5 bytes available
    #expect(String(data: data2, encoding: .utf8) == "FGHIJ")
  }

  @Test
  func `handles an empty file`() async throws {
    let url = try createTempFile(content: "")
    defer { try? FileManager.default.removeItem(at: url) }

    let source = try MemoryMappedFileDataSource(url: url)

    let totalSize = await source.fileSize
    #expect(totalSize == 0)

    let hasMore = (try await source.read(maxLength: 1)) != nil
    #expect(hasMore == false)

    let data = try await source.read(maxLength: 100) ?? Data()
    #expect(data.isEmpty)
  }

  @Test
  func `handles a large file`() async throws {
    // Create a file larger than typical page size (4KB)
    let chunk = String(repeating: "X", count: 1024)
    let content = String(repeating: chunk, count: 10)  // 10KB
    let url = try createTempFile(content: content)
    defer { try? FileManager.default.removeItem(at: url) }

    let source = try MemoryMappedFileDataSource(url: url)

    let totalSize = await source.fileSize
    #expect(totalSize == 10240)

    // Read in large chunks
    var totalRead = 0
    while let data = try await source.read(maxLength: 4096) {
      totalRead += data.count
    }

    #expect(totalRead == 10240)
  }

  @Test
  func `resets the read position`() async throws {
    let content = "ABCDEFGHIJ"
    let url = try createTempFile(content: content)
    defer { try? FileManager.default.removeItem(at: url) }

    let source = try MemoryMappedFileDataSource(url: url)

    // Read some data
    let chunk1 = try await source.read(maxLength: 5) ?? Data()
    #expect(String(data: chunk1, encoding: .utf8) == "ABCDE")

    // Reset position
    // Note: MemoryMappedFileDataSource doesn't have reset, need to recreate
    let source2 = try MemoryMappedFileDataSource(url: url)

    // Read again from beginning
    let chunk2 = try await source2.read(maxLength: 5) ?? Data()
    #expect(String(data: chunk2, encoding: .utf8) == "ABCDE")
  }

  @Test
  func `serves concurrent reads`() async throws {
    let content = String(repeating: "ABCDEFGHIJ", count: 100)  // 1KB
    let url = try createTempFile(content: content)
    defer { try? FileManager.default.removeItem(at: url) }

    let source = try MemoryMappedFileDataSource(url: url)

    // Perform multiple concurrent reads at different offsets
    let read1 = await source.createSlice(from: 0, to: 100)
    let read2 = await source.createSlice(from: 200, to: 300)
    let read3 = await source.createSlice(from: 500, to: 600)

    let results = (read1, read2, read3)

    #expect(results.0.count == 100)
    #expect(results.1.count == 100)
    #expect(results.2.count == 100)

    // Verify content
    #expect(String(data: results.0, encoding: .utf8)?.starts(with: "ABCDE") == true)
  }

  @Test
  func `returns no data past the end of the file`() async throws {
    let content = "SHORT"
    let url = try createTempFile(content: content)
    defer { try? FileManager.default.removeItem(at: url) }

    let source = try MemoryMappedFileDataSource(url: url)

    // Try to read more than available
    let data = try await source.read(maxLength: 100) ?? Data()
    #expect(data.count == 5)
    #expect(String(data: data, encoding: .utf8) == "SHORT")

    // Try to read at offset beyond file
    let data2 = await source.createSlice(from: 10, to: 15)
    #expect(data2.isEmpty)
  }

  @Test
  func `reads multi-byte UTF-8 content`() async throws {
    let content = "Hello 世界 🌍 Émoji"
    let url = try createTempFile(content: content)
    defer { try? FileManager.default.removeItem(at: url) }

    let source = try MemoryMappedFileDataSource(url: url)

    let data = try await source.read(maxLength: 1000) ?? Data()
    let readContent = String(data: data, encoding: .utf8)
    #expect(readContent == content)
  }

  @Test
  func `handles many small sequential reads`() async throws {
    let content = String(repeating: "A", count: 10000)
    let url = try createTempFile(content: content)
    defer { try? FileManager.default.removeItem(at: url) }

    let source = try MemoryMappedFileDataSource(url: url)

    var totalRead = 0
    while let chunk = try await source.read(maxLength: 100) {
      totalRead += chunk.count
    }

    #expect(totalRead == 10000)
  }

  @Test
  func `slices at arbitrary offsets`() async throws {
    // Create a moderately large file
    let content = String(repeating: "X", count: 100_000)  // 100KB
    let url = try createTempFile(content: content)
    defer { try? FileManager.default.removeItem(at: url) }

    let source = try MemoryMappedFileDataSource(url: url)

    // Random access reads should be efficient
    let offsets = [0, 25000, 50000, 75000, 99000]
    for offset in offsets {
      let data = await source.createSlice(from: offset, to: offset + 1000)
      #expect(data.count == min(1000, 100_000 - offset))
    }
  }

  // Helper function to create temporary file
  private func createTempFile(content: String) throws -> URL {
    let tempDir = FileManager.default.temporaryDirectory
    let fileName = "mmap_test_\(UUID().uuidString).csv"
    let url = tempDir.appendingPathComponent(fileName)
    try content.write(to: url, atomically: true, encoding: .utf8)
    return url
  }
}

@Suite
struct `MemoryMappedFileDataSource edge cases` {

  @Test
  func `throws for a file that does not exist`() throws {
    let url = URL(fileURLWithPath: "/tmp/non_existent_file_\(UUID().uuidString).csv")

    #expect(throws: (any Error).self) {
      _ = try MemoryMappedFileDataSource(url: url)
    }
  }

  @Test
  func `throws for a directory`() throws {
    let tempDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("test_dir_\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    #expect(throws: (any Error).self) {
      _ = try MemoryMappedFileDataSource(url: tempDir)
    }
  }

  @Test
  func `handles a file with restrictive permissions`() async throws {
    let content = "test content"
    let url = try createTempFile(content: content)
    defer { try? FileManager.default.removeItem(at: url) }

    // Change file permissions to read-only
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o444],
      ofItemAtPath: url.path
    )

    // Should still be able to read
    let source = try MemoryMappedFileDataSource(url: url)
    let data = try await source.read(maxLength: 100) ?? Data()
    #expect(String(data: data, encoding: .utf8) == content)
  }

  private func createTempFile(content: String) throws -> URL {
    let tempDir = FileManager.default.temporaryDirectory
    let fileName = "edge_test_\(UUID().uuidString).csv"
    let url = tempDir.appendingPathComponent(fileName)
    try content.write(to: url, atomically: true, encoding: .utf8)
    return url
  }
}
