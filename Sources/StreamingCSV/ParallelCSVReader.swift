public import Foundation

/// A parallel CSV reader for processing large files using multiple cores
public actor ParallelCSVReader {
  /// How much of the file is read at a time when scanning for the row boundary
  /// a chunk should start on.
  private static let boundarySearchWindow = 64 * 1024

  private let fileURL: URL
  private let parser: ByteCSVParser
  private let encoding: String.Encoding
  private let parallelism: Int

  /// Initialize a parallel CSV reader
  public init(
    url: URL,
    delimiter: Character = ",",
    quote: Character = "\"",
    escape: Character = "\"",
    encoding: String.Encoding = .utf8,
    parallelism: Int? = nil
  ) {
    self.fileURL = url
    self.parser = ByteCSVParser(delimiter: delimiter, quote: quote, escape: escape)
    self.encoding = encoding
    // Default to number of available cores, capped at 4 for CSV processing
    self.parallelism = min(parallelism ?? ProcessInfo.processInfo.activeProcessorCount, 4)
  }

  /// Process CSV file in parallel, returning all rows
  /// Best for files that fit in memory but are large enough to benefit from parallelization
  public func readAllRows() async throws -> ParallelResult {
    let startTime = Date()

    // Memory map the file
    let dataSource = try MemoryMappedFileDataSource(url: fileURL)

    // Check if file is large enough for parallel processing
    guard await dataSource.canParallelProcess else {
      // Fall back to sequential processing for small files
      return try await readSequentially(dataSource: dataSource, startTime: startTime)
    }

    let chunks = await chunkRanges(in: dataSource)

    // Process chunks in parallel
    let results = try await withThrowingTaskGroup(of: [[String]].self) { group in
      for chunk in chunks {
        group.addTask { [parser, encoding] in
          let chunkData = await dataSource.createSlice(
            from: chunk.lowerBound,
            to: chunk.upperBound
          )
          return await self.parseChunk(data: chunkData, parser: parser, encoding: encoding)
        }
      }

      var allRows: [[String]] = []
      for try await chunkRows in group {
        allRows.append(contentsOf: chunkRows)
      }
      return allRows
    }

    let processingTime = Date().timeIntervalSince(startTime)
    return ParallelResult(
      rows: results,
      totalRows: results.count,
      processingTime: processingTime
    )
  }

  /// Process CSV file in parallel with a row handler
  /// Best for very large files that don't fit in memory
  public func processRows(handler: @escaping @Sendable ([String]) async -> Void) async throws {
    // Memory map the file
    let dataSource = try MemoryMappedFileDataSource(url: fileURL)

    guard await dataSource.canParallelProcess else {
      // Fall back to sequential processing
      try await processSequentially(dataSource: dataSource, handler: handler)
      return
    }

    let chunks = await chunkRanges(in: dataSource)

    // Create an actor to handle ordered processing
    let accumulator = RowAccumulator(handler: handler)

    try await withThrowingTaskGroup(of: (index: Int, rows: [[String]]).self) { group in
      for (index, chunk) in chunks.enumerated() {
        group.addTask { [parser, encoding] in
          let chunkData = await dataSource.createSlice(
            from: chunk.lowerBound,
            to: chunk.upperBound
          )
          let rows = await self.parseChunk(data: chunkData, parser: parser, encoding: encoding)
          return (index: index, rows: rows)
        }
      }

      // Collect and process results in order
      var chunks: [(index: Int, rows: [[String]])] = []
      for try await chunk in group {
        chunks.append(chunk)
      }

      // Sort by index to maintain row order
      chunks.sort { $0.index < $1.index }

      // Process rows in order
      for chunk in chunks {
        for row in chunk.rows {
          await accumulator.processRow(row)
        }
      }
    }
  }

  // Helper methods

  private func parseChunk(data: Data, parser: ByteCSVParser, encoding _: String.Encoding)
    -> [[String]]
  {
    var rows: [[String]] = []
    var offset = 0

    while offset < data.count {
      let remainingCount = data.count - offset
      guard remainingCount > 0 else { break }

      // Create a slice without copying
      let startIndex = data.startIndex.advanced(by: offset)
      let endIndex = data.endIndex
      let remainingData = data[startIndex..<endIndex]

      // Check if this is the last chunk of data
      let isEndOfChunk = offset + remainingCount >= data.count

      if let result = parser.parseRow(from: remainingData, isEndOfFile: isEndOfChunk) {
        rows.append(result.row.stringFields)
        offset += result.consumedBytes
      } else {
        // No complete row found in remaining data
        break
      }
    }

    return rows
  }

  /// The byte ranges the workers parse, in file order.
  ///
  /// Every cut falls on the start of a row, and one chunk ends exactly where the
  /// next begins, so each row is parsed once by exactly one worker. Cutting at
  /// the raw offsets instead would hand the row straddling a cut to two workers:
  /// once truncated, once whole.
  private func chunkRanges(in dataSource: MemoryMappedFileDataSource) async -> [Range<Int>] {
    let fileSize = await dataSource.fileSize
    let chunkSize = fileSize / parallelism

    var boundaries = [0]
    for i in 1..<parallelism {
      let boundary = await rowStart(atOrAfter: i * chunkSize, in: dataSource)
      // A row longer than a chunk can carry one boundary past the next, which
      // would leave the chunks between them empty and out of order.
      guard let previous = boundaries.last, boundary > previous else { continue }
      boundaries.append(boundary)
    }
    if let previous = boundaries.last, fileSize > previous { boundaries.append(fileSize) }

    return zip(boundaries, boundaries.dropFirst()).map { $0..<$1 }
  }

  /// The offset of the first row beginning at or after `offset`, or the end of
  /// the file when no row does.
  private func rowStart(atOrAfter offset: Int, in dataSource: MemoryMappedFileDataSource) async
    -> Int
  {
    let fileSize = await dataSource.fileSize
    var searchStart = offset

    while searchStart < fileSize {
      let searchEnd = min(fileSize, searchStart + Self.boundarySearchWindow)
      let searchData = await dataSource.createSlice(from: searchStart, to: searchEnd)
      if let boundary = parser.findRowBoundary(in: searchData, startingAt: 0) {
        return searchStart + boundary
      }
      searchStart = searchEnd
    }

    return fileSize
  }

  private func readSequentially(dataSource: MemoryMappedFileDataSource, startTime: Date)
    async throws -> ParallelResult
  {
    var rows: [[String]] = []
    var offset = 0
    let data = await dataSource.createSlice(from: 0, to: await dataSource.fileSize)

    while offset < data.count {
      let remainingCount = data.count - offset
      guard remainingCount > 0 else { break }

      let startIndex = data.startIndex.advanced(by: offset)
      let endIndex = data.endIndex
      let remainingData = data[startIndex..<endIndex]
      let isEndOfFile = offset + remainingCount >= data.count

      if let result = parser.parseRow(from: Data(remainingData), isEndOfFile: isEndOfFile) {
        rows.append(result.row.stringFields)
        offset += result.consumedBytes
      } else {
        break
      }
    }

    let processingTime = Date().timeIntervalSince(startTime)
    return ParallelResult(
      rows: rows,
      totalRows: rows.count,
      processingTime: processingTime
    )
  }

  private func processSequentially(
    dataSource: MemoryMappedFileDataSource,
    handler: @escaping @Sendable ([String]) async -> Void
  ) async throws {
    var offset = 0
    let data = await dataSource.createSlice(from: 0, to: await dataSource.fileSize)

    while offset < data.count {
      let remainingCount = data.count - offset
      guard remainingCount > 0 else { break }

      let startIndex = data.startIndex.advanced(by: offset)
      let endIndex = data.endIndex
      let remainingData = data[startIndex..<endIndex]
      let isEndOfFile = offset + remainingCount >= data.count

      if let result = parser.parseRow(from: Data(remainingData), isEndOfFile: isEndOfFile) {
        await handler(result.row.stringFields)
        offset += result.consumedBytes
      } else {
        break
      }
    }
  }

  /// Result of parallel CSV processing
  public struct ParallelResult: Sendable {
    /// The parsed CSV rows
    public let rows: [[String]]

    /// Total number of rows processed
    public let totalRows: Int

    /// Time taken to process the CSV file
    public let processingTime: TimeInterval
  }
}

/// Actor to accumulate and process rows in order
private actor RowAccumulator {
  private let handler: @Sendable ([String]) async -> Void

  init(handler: @escaping @Sendable ([String]) async -> Void) {
    self.handler = handler
  }

  func processRow(_ row: [String]) async {
    await handler(row)
  }
}
