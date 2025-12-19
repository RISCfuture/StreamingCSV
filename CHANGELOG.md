# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
