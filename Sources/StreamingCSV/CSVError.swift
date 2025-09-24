import Foundation

/// Errors that can occur during CSV processing.
///
/// `CSVError` represents various failure conditions that may occur when reading or
/// writing CSV data.
public enum CSVError: Error, LocalizedError {
  /**
   The data could not be encoded or decoded using the specified text encoding.
  
   This error occurs when:
   - Binary data cannot be interpreted using the specified encoding when
     reading
   - String data cannot be converted to the specified encoding when writing
   */
  case encodingError

  /**
   The provided URL is invalid or not supported.
  
   This error occurs when:
   - A file URL is expected but a different scheme is provided
   - A network URL is expected but a file URL is provided
   */
  case invalidURL

  /**
   A network error occurred during data transfer.
  
   This error occurs when:
   - HTTP request fails
   - Response status code indicates an error
   - Network connection is lost
   */
  case networkError

  public var errorDescription: String? {
    switch self {
      case .encodingError:
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
          return String(
            localized: "CSV Encoding Error",
            bundle: .module,
            comment: "Error when CSV encoding/decoding fails"
          )
        #else
          return "CSV Encoding Error"
        #endif
      case .invalidURL:
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
          return String(
            localized: "Invalid URL",
            bundle: .module,
            comment: "Error when URL is invalid"
          )
        #else
          return "Invalid URL"
        #endif
      case .networkError:
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
          return String(
            localized: "Network Error",
            bundle: .module,
            comment: "Error during network operation"
          )
        #else
          return "Network Error"
        #endif
    }
  }

  public var failureReason: String? {
    switch self {
      case .encodingError:
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
          return String(
            localized:
              "The data could not be encoded or decoded using the specified text encoding.",
            bundle: .module,
            comment: "CSV encoding error reason"
          )
        #else
          return "The data could not be encoded or decoded using the specified text encoding."
        #endif
      case .invalidURL:
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
          return String(
            localized: "The URL provided is not valid or uses an unsupported scheme.",
            bundle: .module,
            comment: "Invalid URL error reason"
          )
        #else
          return "The URL provided is not valid or uses an unsupported scheme."
        #endif
      case .networkError:
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
          return String(
            localized: "Failed to download data from the network.",
            bundle: .module,
            comment: "Network error reason"
          )
        #else
          return "Failed to download data from the network."
        #endif
    }
  }

  public var recoverySuggestion: String? {
    switch self {
      case .encodingError:
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
          return String(
            localized:
              "Ensure the file is saved with the correct text encoding and contains valid characters for that encoding.",
            bundle: .module,
            comment: "CSV encoding error suggestion"
          )
        #else
          return
            "Ensure the file is saved with the correct text encoding and contains valid characters for that encoding."
        #endif
      case .invalidURL:
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
          return String(
            localized:
              "Check that the URL is properly formatted and uses the correct scheme (file://, http://, or https://).",
            bundle: .module,
            comment: "Invalid URL error suggestion"
          )
        #else
          return
            "Check that the URL is properly formatted and uses the correct scheme (file://, http://, or https://)."
        #endif
      case .networkError:
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
          return String(
            localized: "Check your network connection and ensure the URL is accessible.",
            bundle: .module,
            comment: "Network error suggestion"
          )
        #else
          return "Check your network connection and ensure the URL is accessible."
        #endif
    }
  }
}
