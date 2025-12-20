import Foundation

/// An asynchronous sequence that transforms a stream of Data chunks into CSV rows.
///
/// `CSVRowStream` provides streaming CSV parsing without buffering the entire
/// input into memory. It consumes an `AsyncSequence` of `Data` chunks and produces
/// `CSVRowBytes` elements as they are parsed.
///
/// This is ideal for processing large CSV files from sources that deliver data in chunks,
/// such as network responses or archive extraction.
///
/// ## Example
///
/// ```swift
/// let dataStream: AsyncThrowingStream<Data, Error> = ...
/// let rowStream = CSVRowStream(source: dataStream)
///
/// for try await row in rowStream {
///     print(row.stringFields)
/// }
/// ```
///
/// ## Key Features
///
/// - **Streaming**: Rows are parsed and yielded as data arrives
/// - **Memory Efficient**: Only buffers enough data to parse complete rows
/// - **Composable**: Works with Swift's async sequence ecosystem (`map`, `filter`, etc.)
/// - **Backpressure**: Automatically handles backpressure through async iteration
///
/// ## See Also
/// - ``TypedCSVRowStream``
/// - ``CSVRowBytes``
public struct CSVRowStream<Source: AsyncSequence & Sendable>: AsyncSequence, Sendable
where Source.Element == Data {
  public typealias Element = CSVRowBytes

  private let source: Source
  private let delimiter: Character
  private let quote: Character
  private let escape: Character
  private let encoding: String.Encoding
  private let initialBufferCapacity: Int

  /// Creates a new CSV row stream from an async sequence of Data chunks.
  ///
  /// - Parameters:
  ///   - source: The async sequence of Data chunks to parse.
  ///   - delimiter: The character used to separate fields. Defaults to comma (`,`).
  ///   - quote: The character used to quote fields. Defaults to double quote (`"`).
  ///   - escape: The character used to escape quotes. Defaults to double quote (`"`).
  ///   - encoding: The string encoding to use. Defaults to UTF-8.
  ///   - bufferCapacity: Initial buffer capacity in bytes. Defaults to 65536 (64KB).
  public init(
    source: Source,
    delimiter: Character = ",",
    quote: Character = "\"",
    escape: Character = "\"",
    encoding: String.Encoding = .utf8,
    bufferCapacity: Int = 65536
  ) {
    self.source = source
    self.delimiter = delimiter
    self.quote = quote
    self.escape = escape
    self.encoding = encoding
    self.initialBufferCapacity = bufferCapacity
  }

  public func makeAsyncIterator() -> AsyncIterator {
    AsyncIterator(
      sourceIterator: source.makeAsyncIterator(),
      parser: ByteCSVParser(
        delimiter: delimiter,
        quote: quote,
        escape: escape,
        encoding: encoding
      ),
      bufferCapacity: initialBufferCapacity
    )
  }

  /// The async iterator that parses CSV rows from the data stream.
  public struct AsyncIterator: AsyncIteratorProtocol {
    private var sourceIterator: Source.AsyncIterator
    private let parser: ByteCSVParser
    private var buffer: Data
    private var isSourceExhausted: Bool = false
    private var lastRowEndedWithCR: Bool = false

    init(
      sourceIterator: Source.AsyncIterator,
      parser: ByteCSVParser,
      bufferCapacity: Int
    ) {
      self.sourceIterator = sourceIterator
      self.parser = parser
      self.buffer = Data()
      self.buffer.reserveCapacity(bufferCapacity)
    }

    public mutating func next() async throws -> CSVRowBytes? {
      // Line feed and carriage return bytes
      let lf: UInt8 = 0x0A  // \n
      let cr: UInt8 = 0x0D  // \r

      while true {
        // If the last row ended with a lone CR and buffer starts with LF, skip the LF
        // This handles CRLF split across chunk boundaries
        if lastRowEndedWithCR {
          if !buffer.isEmpty {
            if buffer[buffer.startIndex] == lf {
              buffer.removeFirst(1)
            }
            // Only reset the flag once we've had a chance to check
            lastRowEndedWithCR = false
          }
          // If buffer is empty, keep the flag set until we get more data
        }

        // Try to parse a complete row from the buffer
        if let result = parser.parseRow(from: buffer, isEndOfFile: isSourceExhausted) {
          // Check if this row ended with a lone CR (CR at end of buffer without LF following)
          let consumed = result.consumedBytes
          if consumed > 0 && buffer[buffer.startIndex + consumed - 1] == cr {
            // Row ended with CR - check if there was no LF after it
            if consumed == buffer.count || buffer[buffer.startIndex + consumed] != lf {
              lastRowEndedWithCR = true
            }
          }

          // Remove consumed bytes from buffer
          buffer.removeFirst(result.consumedBytes)
          return result.row
        }

        // No complete row found - need more data
        guard !isSourceExhausted else {
          // No more data and no complete row - we're done
          return nil
        }

        // Try to get more data from source
        if let chunk = try await sourceIterator.next() {
          buffer.append(chunk)
        } else {
          // Source is exhausted - try one more parse with isEndOfFile=true
          isSourceExhausted = true
          // Loop will try parsing again with isEndOfFile=true
        }
      }
    }
  }
}

/// Extension for convenient initialization with common async sequence types.
extension CSVRowStream {
  /// Creates a new CSV row stream with default parsing options.
  ///
  /// - Parameter source: The async sequence of Data chunks to parse.
  public init(_ source: Source) {
    self.init(source: source)
  }
}
