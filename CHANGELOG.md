# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- `ParallelCSVReader` cut each worker's chunk at a raw byte offset while
  starting the next worker on a row boundary, so the row straddling every cut
  was parsed twice — once truncated, once whole — and the rows between the
  adjusted start and the unadjusted end were parsed twice over. Both
  `readAllRows()` and `processRows(handler:)` now share one partition whose
  every cut falls on the start of a row. Only files past
  `MemoryMappedFileDataSource`'s size threshold are chunked, so smaller files
  were never affected.
- The scan for a chunk's starting row boundary searched a fixed 1 KB window and
  silently fell back to the unaligned offset when it found no line ending. It
  now keeps reading until it finds one, so a row longer than the window no
  longer splits.

## [2.1.1] - 2026-09-14

### Changed

- Raise the minimum dependency versions to swift-syntax 603.0.2,
  swift-macro-toolkit 0.9.0, and swift-docc-plugin 1.5.0.
- Build the package in Swift language mode 5 as well as mode 6, so consumers
  on either mode can depend on it. `swift-tools-version` stays at 6.3.

### Internal

- Adopt the `ImmutableWeakCaptures`, `MemberImportVisibility`,
  `ExistentialAny`, and `InternalImportsByDefault` upcoming-feature flags
  across every target, alongside the approachable-concurrency flags already
  in place. The fallout was limited to import-visibility annotations and
  explicit `any` spellings; no public API changed.

## [2.1.0] - 2026-06-26

### Changed

- Adopt the Approachable Concurrency upcoming-feature flags
  (`NonisolatedNonsendingByDefault` and `InferIsolatedConformances`).
  Existing public async behavior is preserved — the `CSVRowStream` and
  `TypedCSVRowStream` row iterators continue to run off the caller's
  executor — so this is a non-source-breaking concurrency modernization.

### Internal

- Remove an unaudited `@unchecked Sendable` escape hatch from the internal
  `CSVByteBuffer`. The buffer is exclusively owned and serialized by the
  `StreamingCSVReader` actor, so the conformance was unnecessary and the
  type is now a plain actor-confined reference.

## [2.0.0] 2025-12-21

### Added

- Add `CSVRowStream` and `TypedCSVRowStream` for streaming CSV parsing from
  `AsyncSequence<Data>` sources without buffering entire files into memory.
- Add `StreamingCSVReader.stream(from:)` factory methods for convenient stream
  creation.

### Removed

- Remove `AsyncDataStreamDataSource` and the `dataStream` initializer on
  `StreamingCSVReader`. Use the new `stream(from:)` factory methods instead.

## [1.1.2] - 2025-12-19

- Add byte count tracking for progress

## [1.1.1] - 2025-09-12

### Fixed

- Fixed bug caused by escaped rows crossing buffer boundaries.

## [1.1.0] - 2025-09-11

### Added

- New `@Fields` macro for handling array fields in CSV files
  - `@Fields(n)` for fixed-size arrays with automatic padding
  - `@Fields` for collecting all remaining fields
- New specialized macros for read-only and write-only CSV operations:
  - `@CSVRowDecoderBuilder` - For types that only need to parse CSV data
    (requires only `CSVDecodable`)
  - `@CSVRowEncoderBuilder` - For types that only need to generate CSV data
    (requires only `CSVEncodable`)
- New protocols for better separation of concerns:
  - `CSVDecodableRow` - Protocol for types that can be decoded from CSV rows
  - `CSVEncodableRow` - Protocol for types that can be encoded to CSV rows
  - `CSVRow` now combines both protocols for bidirectional support

### Changed

- `CSVRow` protocol is now composed of `CSVDecodableRow` and `CSVEncodableRow`
- Added `CSVCodable` conformance to common `RawRepresentable` enum types

### Fixed

- Fixed issue where `Optional` types couldn't conform to `CSVCodable` due to
  separate protocol extensions

## [1.0.0] - 2025-09-11

### Added

- Initial release of StreamingCSV.
