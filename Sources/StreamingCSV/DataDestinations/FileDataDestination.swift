import Foundation

/**
 A data destination that writes CSV data to a local file.
 
 `FileDataDestination` provides streaming write access to files on the local
 filesystem using `FileHandle`. It supports both creating new files and
 appending to existing files.
 
 ## Example
 
 ```swift
 let destination = try FileDataDestination(url: outputURL)
 // Use with StreamingCSVWriter
 ```
 */
public actor FileDataDestination: CSVDataDestination {
    private let fileHandle: FileHandle

    /**
     Creates a new file data destination.
     
     - Parameters:
       - url: The URL where the file will be written. Must be a file URL.
       - append: If `true`, appends to an existing file. If `false`, overwrites
         any existing file. Defaults to `false`.
     - Throws: An error if the file cannot be opened for writing.
     */
    public init(url: URL, append: Bool = false) throws {
        guard url.isFileURL else {
            throw CSVError.invalidURL
        }

        if !append && FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }

        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }

        self.fileHandle = try FileHandle(forWritingTo: url)
        if append {
            _ = fileHandle.seekToEndOfFile()
        }
    }

    public func write(_ data: Data) throws {
        fileHandle.write(data)
    }

    public func flush() throws {
        // FileHandle doesn't have an explicit flush, but synchronizeFile is similar
        fileHandle.synchronizeFile()
    }

    public func close() throws {
        try fileHandle.close()
    }

    deinit {
        try? fileHandle.close()
    }
}
