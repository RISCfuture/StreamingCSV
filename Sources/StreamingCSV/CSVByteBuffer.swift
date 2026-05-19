import Foundation

final class CSVByteBuffer: @unchecked Sendable {
  @usableFromInline internal var buffer: [UInt8]
  @usableFromInline internal var readIndex: Int = 0
  @usableFromInline internal var writeIndex: Int = 0
  private let initialCapacity: Int

  var readableBytes: Int {
    return writeIndex - readIndex
  }

  var isEmpty: Bool {
    return readIndex >= writeIndex
  }

  var capacity: Int {
    return buffer.capacity
  }

  init(capacity: Int = 65536) {
    self.initialCapacity = capacity
    self.buffer = []
    self.buffer.reserveCapacity(capacity)
  }

  // MARK: - Methods

  @discardableResult
  func write(_ data: Data) -> Int {
    let bytesToWrite = data.count

    // Ensure we have enough capacity
    let requiredCapacity = writeIndex + bytesToWrite
    if requiredCapacity > buffer.capacity {
      buffer.reserveCapacity(requiredCapacity * 2)
    }

    data.withUnsafeBytes { bytes in
      let ptr = bytes.bindMemory(to: UInt8.self)
      for i in 0..<bytesToWrite {
        buffer.append(ptr[i])
        writeIndex += 1
      }
    }
    return bytesToWrite
  }

  func peek(count: Int) -> Data? {
    let availableBytes = min(count, readableBytes)
    guard availableBytes > 0 else { return nil }

    return Data(buffer[readIndex..<(readIndex + availableBytes)])
  }

  func read(count: Int) -> Data? {
    let availableBytes = min(count, readableBytes)
    guard availableBytes > 0 else { return nil }

    let result = Data(buffer[readIndex..<(readIndex + availableBytes)])
    readIndex += availableBytes
    return result
  }

  @discardableResult
  func skip(count: Int) -> Int {
    let bytesToSkip = min(count, readableBytes)
    readIndex += bytesToSkip
    return bytesToSkip
  }

  func findByte(_ byte: UInt8, maxLength: Int? = nil) -> Int? {
    let searchLength = min(maxLength ?? readableBytes, readableBytes)
    guard searchLength > 0 else { return nil }

    let endIndex = readIndex + searchLength
    for i in readIndex..<endIndex where buffer[i] == byte {
      return i - readIndex
    }
    return nil
  }

  func clear() {
    buffer.removeAll(keepingCapacity: true)
    readIndex = 0
    writeIndex = 0
  }

  func compact() {
    guard readIndex > 0 else { return }

    if readIndex >= writeIndex {
      // All data has been read, just reset
      clear()
    } else {
      // Move unread data to the beginning
      let unreadBytes = readableBytes
      buffer.removeFirst(readIndex)
      readIndex = 0
      writeIndex = unreadBytes

      // Shrink buffer if it's gotten too large
      if buffer.capacity > initialCapacity * 4 && buffer.count < initialCapacity {
        buffer.reserveCapacity(initialCapacity)
      }
    }
  }

  deinit {
    buffer.removeAll()
  }
}
