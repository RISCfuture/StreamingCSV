import Foundation

/**
 A parser for CSV (Comma-Separated Values) format data.
 
 `CSVParser` handles the parsing and formatting of CSV data, including proper
 handling of quoted fields, escaped characters, and multi-line values.

 ## Topics

 ### Creating a Parser

 - ``init(delimiter:quote:escape:)``
 
 ### Parsing CSV Data

 - ``parseRow(from:)``
 - ``parseRows(from:)``
 
 ### Formatting CSV Data

 - ``formatField(_:)``
 - ``formatRow(_:)``
 */
public struct CSVParser {

    /// The character used to separate fields in a CSV row.
    public let delimiter: Character

    /// The character used to quote fields containing special characters.
    public let quote: Character

    /// The character used to escape quotes within quoted fields.
    public let escape: Character

    /**
     Creates a new CSV parser with the specified configuration.
     
     - Parameters:
       - delimiter: The character to use for separating fields. Defaults to
         comma (`,`).
       - quote: The character to use for quoting fields. Defaults to double
         quote (`"`).
       - escape: The character to use for escaping quotes. Defaults to double
         quote (`"`).
     */
    public init(delimiter: Character = ",", quote: Character = "\"", escape: Character = "\"") {
        self.delimiter = delimiter
        self.quote = quote
        self.escape = escape
    }

    /**
     Parses a single CSV row string into an array of field values.
     
     This method properly handles:
     - Quoted fields containing delimiters, newlines, or quotes
     - Escaped quotes within quoted fields
     - Empty fields
     - Whitespace preservation within fields
     
     - Parameter line: The CSV row string to parse.
     - Returns: An array of field values extracted from the CSV row.
     */
    public func parseRow(from line: String) -> [String] {
        var fields: [String] = []
        var currentField = ""
        var inQuotes = false
        var escapeNext = false

        let characters = Array(line)
        var index = 0

        while index < characters.count {
            let char = characters[index]

            if escapeNext {
                currentField.append(char)
                escapeNext = false
                index += 1
                continue
            }

            if char == escape && inQuotes {
                if index + 1 < characters.count && characters[index + 1] == quote {
                    currentField.append(quote)
                    index += 2
                    continue
                }
            }

            if char == quote {
                if inQuotes {
                    inQuotes = false
                } else if currentField.isEmpty || (index > 0 && characters[index - 1] == delimiter) {
                    inQuotes = true
                } else {
                    currentField.append(char)
                }
            } else if char == delimiter && !inQuotes {
                fields.append(currentField)
                currentField = ""
            } else {
                currentField.append(char)
            }

            index += 1
        }

        fields.append(currentField)
        return fields
    }

    /**
     Parses multiple CSV rows from a text string.
     
     This method handles multi-line fields properly by tracking quote state
     across line breaks. It automatically handles both Unix (`\n`) and Windows
     (`\r\n`) line endings.

     - Parameter text: The CSV text containing multiple rows.
     - Returns: An array of arrays, where each inner array represents the fields of a CSV row.
     */
    public func parseRows(from text: String) -> [[String]] {
        var rows: [[String]] = []
        var currentRow = ""
        var inQuotes = false

        for char in text {
            currentRow.append(char)

            if char == quote {
                inQuotes.toggle()
            } else if char == "\n" && !inQuotes {
                if currentRow.hasSuffix("\r\n") && currentRow.count >= 2 {
                    currentRow.removeLast(2)
                } else if currentRow.count >= 1 {
                    currentRow.removeLast()
                }

                if !currentRow.isEmpty {
                    rows.append(parseRow(from: currentRow))
                }
                currentRow = ""
            }
        }

        if !currentRow.isEmpty {
            rows.append(parseRow(from: currentRow))
        }

        return rows
    }

    /**
     Formats a single field value for CSV output.
     
     This method automatically quotes fields that contain special characters
     such as:

     - The delimiter character
     - Quote characters (which are also escaped)
     - Newline characters
     - Carriage return characters
     
     - Parameter field: The field value to format.
     - Returns: The formatted field value, quoted and escaped if necessary.
     */
    public func formatField(_ field: String) -> String {
        let needsQuoting = field.contains(String(delimiter)) ||
                          field.contains(String(quote)) ||
                          field.contains("\n") ||
                          field.contains("\r")

        if needsQuoting {
            let escaped = field.replacingOccurrences(of: String(quote), with: String(escape) + String(quote))
            return "\(quote)\(escaped)\(quote)"
        }

        return field
    }

    /**
     Formats an array of field values into a CSV row string.
     
     Each field is automatically quoted and escaped as necessary using
     ``formatField(_:)``.
     The fields are then joined with the delimiter character.
     
     - Parameter fields: An array of field values to format.
     - Returns: A properly formatted CSV row string.
     */
    public func formatRow(_ fields: [String]) -> String {
        fields.map { formatField($0) }.joined(separator: String(delimiter))
    }
}
