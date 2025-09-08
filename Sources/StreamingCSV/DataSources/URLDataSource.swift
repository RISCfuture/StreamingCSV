import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/**
 A data source that reads CSV data from a network URL.
 
 `URLDataSource` downloads CSV data from HTTP/HTTPS URLs using `URLSession`.
 It supports streaming large files efficiently without loading the entire
 content into memory at once.
 
 ## Example
 
 ```swift
 let source = try await URLDataSource(url: csvURL)
 // Use with StreamingCSVReader
 ```
 
 ## Progress Tracking
 
 You can optionally provide a progress handler to track download progress:
 
 ```swift
 let source = try await URLDataSource(
     url: csvURL,
     progressHandler: { bytesReceived, totalBytes in
         let percent = Double(bytesReceived) / Double(totalBytes ?? 1) * 100
         print("Downloaded: \(percent)%")
     }
 )
 ```
 */
public actor URLDataSource: CSVDataSource {
    private let data: Data
    private var position: Int = 0
    private let bufferSize: Int

    /**
     Creates a new URL data source by downloading from the specified URL.
     
     This initializer downloads the entire content into memory before processing.
     For very large files, consider using streaming alternatives.
     
     - Parameters:
       - url: The URL to download CSV data from. Must be an HTTP or HTTPS URL.
       - bufferSize: The size of the read buffer in bytes. Defaults to 65536 (64KB).
       - session: The URLSession to use for downloading. Defaults to shared session.
       - progressHandler: Optional closure called periodically with download progress.
     - Throws: An error if the download fails or the URL is invalid.
     */
    public init(
        url: URL,
        bufferSize: Int = 65536,
        session: URLSession = .shared,
        progressHandler: (@Sendable (Int64, Int64?) -> Void)? = nil
    ) async throws {
        guard url.scheme == "http" || url.scheme == "https" else {
            throw CSVError.invalidURL
        }

        self.bufferSize = bufferSize

        if let progressHandler {
            // Download with progress tracking
            let delegate = ProgressDelegate(progressHandler: progressHandler)
            let (data, _) = try await session.data(for: URLRequest(url: url), delegate: delegate)
            self.data = data
        } else {
            // Simple download
            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw CSVError.networkError
            }

            self.data = data
        }
    }

    public func read(maxLength: Int) throws -> Data? {
        guard position < data.count else { return nil }

        let readLength = min(maxLength, bufferSize, data.count - position)
        let endPosition = position + readLength

        let chunk = data[position..<endPosition]
        position = endPosition

        return chunk.isEmpty ? nil : chunk
    }

    public func close() throws {
        // No resources to clean up for in-memory data
    }
}

private final class ProgressDelegate: NSObject, URLSessionTaskDelegate, Sendable {
    private let progressHandler: @Sendable (Int64, Int64?) -> Void

    init(progressHandler: @escaping @Sendable (Int64, Int64?) -> Void) {
        self.progressHandler = progressHandler
    }

    func urlSession(
        _: URLSession,
        task _: URLSessionTask,
        didSendBodyData _: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        let expected = totalBytesExpectedToSend != NSURLSessionTransferSizeUnknown
            ? totalBytesExpectedToSend
            : nil
        progressHandler(totalBytesSent, expected)
    }
}
