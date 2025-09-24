import Foundation

actor AdaptiveBufferStrategy {
  private var currentSize: BufferSize
  private var statistics = Statistics()
  private let minRows = 10  // Minimum rows before making size decisions
  private let adjustmentThreshold = 20  // Consecutive over/undersized rows before adjustment

  var bufferSize: Int {
    // Return at least the initial size until we have enough data
    if statistics.totalRows < minRows {
      return currentSize.rawValue
    }
    return currentSize.rawValue
  }

  init(initialSize: BufferSize = .medium) {
    self.currentSize = initialSize
  }

  func recordRow(size: Int) -> Int {
    statistics.recordRow(size: size)

    // Don't adjust until we have enough data
    guard statistics.totalRows >= minRows else {
      return currentSize.rawValue
    }

    // Check if current buffer is appropriate
    let recentAvg = statistics.recentAverageRowSize
    let currentCapacity = currentSize.rawValue

    // Buffer is oversized if average row is less than 10% of buffer
    if recentAvg < currentCapacity / 10 {
      statistics.consecutiveUndersized += 1
      statistics.consecutiveOversized = 0

      if statistics.consecutiveUndersized >= adjustmentThreshold {
        if let smaller = currentSize.nextSmaller {
          currentSize = smaller
          statistics.consecutiveUndersized = 0
        }
      }
    }
    // Buffer is undersized if average row is more than 50% of buffer
    else if recentAvg > currentCapacity / 2 {
      statistics.consecutiveOversized += 1
      statistics.consecutiveUndersized = 0

      if statistics.consecutiveOversized >= adjustmentThreshold / 2 {  // Grow faster
        if let larger = currentSize.nextLarger {
          currentSize = larger
          statistics.consecutiveOversized = 0
        }
      }
    } else {
      // Buffer size is appropriate
      statistics.consecutiveOversized = 0
      statistics.consecutiveUndersized = 0
    }

    return currentSize.rawValue
  }

  func handleOversizedRow(size: Int) -> Int {
    // Immediately jump to a size that can handle this row with some headroom
    let requiredSize = size * 2  // Double the row size for headroom

    for bufferSize in BufferSize.allCases.reversed() where bufferSize.rawValue >= requiredSize {
      currentSize = bufferSize
      return bufferSize.rawValue
    }

    // If even huge isn't enough, return the requested size directly
    return requiredSize
  }

  func getStatistics() -> (
    totalRows: Int,
    averageRowSize: Int,
    recentAverageRowSize: Int,
    currentBufferSize: Int
  ) {
    return (
      statistics.totalRows,
      statistics.averageRowSize,
      statistics.recentAverageRowSize,
      currentSize.rawValue
    )
  }

  func reset(toSize size: BufferSize? = nil) {
    statistics = Statistics()
    if let size {
      currentSize = size
    }
  }

  enum BufferSize: Int, CaseIterable {
    case tiny = 8192  // 8KB for very small rows
    case small = 16384  // 16KB for small rows
    case medium = 65536  // 64KB for medium rows (default)
    case large = 262144  // 256KB for large rows
    case huge = 1_048_576  // 1MB for very large rows

    var nextLarger: BufferSize? {
      switch self {
        case .tiny: return .small
        case .small: return .medium
        case .medium: return .large
        case .large: return .huge
        case .huge: return nil
      }
    }

    var nextSmaller: BufferSize? {
      switch self {
        case .tiny: return nil
        case .small: return .tiny
        case .medium: return .small
        case .large: return .medium
        case .huge: return .large
      }
    }

    static func recommended(for avgRowSize: Int) -> BufferSize {
      switch avgRowSize {
        case 0..<50:
          return .tiny
        case 50..<100:
          return .small
        case 100..<1000:
          return .medium
        case 1000..<5000:
          return .large
        default:
          return .huge
      }
    }
  }

  private struct Statistics {
    var totalRows: Int = 0
    var totalBytes: Int = 0
    var recentRowSizes: [Int] = []
    let recentWindowSize: Int = 100
    var consecutiveOversized: Int = 0
    var consecutiveUndersized: Int = 0

    var averageRowSize: Int {
      guard totalRows > 0 else { return 0 }
      return totalBytes / totalRows
    }

    var recentAverageRowSize: Int {
      guard !recentRowSizes.isEmpty else { return 0 }
      return recentRowSizes.reduce(0, +) / recentRowSizes.count
    }

    mutating func recordRow(size: Int) {
      totalRows += 1
      totalBytes += size

      recentRowSizes.append(size)
      if recentRowSizes.count > recentWindowSize {
        recentRowSizes.removeFirst()
      }
    }
  }
}

struct CSVCharacteristics: Sendable {
  var hasQuotes: Bool = false
  var hasMultilineFields: Bool = false
  var isFixedWidth: Bool = true
  var columnCount: Int?
  var isASCIIOnly: Bool = true
  var averageRowSize: Int = 0

  private var rowCount: Int = 0
  private var totalBytes: Int = 0
  private var columnCounts: [Int] = []

  init() {}

  mutating func observe(rowBytes: CSVRowBytes, rawSize: Int) {
    rowCount += 1
    totalBytes += rawSize
    averageRowSize = totalBytes / rowCount

    // Check for quotes
    if !hasQuotes {
      hasQuotes = rowBytes.fields.contains(where: \.isQuoted)
    }

    // Track column count consistency
    let currentColumns = rowBytes.fields.count
    columnCounts.append(currentColumns)

    if columnCounts.count >= 10 {
      // Check if last 10 rows have same column count
      let last10 = columnCounts.suffix(10)
      if Set(last10).count == 1 {
        columnCount = last10.first
        isFixedWidth = true
      } else {
        isFixedWidth = false
      }
    }

    // Check for ASCII-only content (sampling)
    if isASCIIOnly && rowCount.isMultiple(of: 10) {  // Sample every 10th row
      rowBytes.data.withUnsafeBytes { bytes in
        let ptr = bytes.bindMemory(to: UInt8.self)
        for i in 0..<bytes.count where ptr[i] > 127 {
          isASCIIOnly = false
          break
        }
      }
    }
  }
}
