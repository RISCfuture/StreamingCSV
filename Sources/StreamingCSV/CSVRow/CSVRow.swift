import Foundation

/**
 A type that represents a complete CSV row with multiple fields.
 
 Types conforming to `CSVRow` can be used with ``StreamingCSVReader/readRow()``
 and ``StreamingCSVWriter/writeRow(_:)`` for type-safe CSV operations. The
 protocol requires bidirectional conversion between the type and an array of
 string fields.

 ## Conforming to CSVRow

 You can manually conform to `CSVRow` or use the ``CSVRowBuilder()`` macro for
 automatic implementation:

 ```swift
 @CSVRowBuilder
 struct Person {
     @Field var name: String
     @Field var age: Int
     @Field var city: String
 }
 ```
 */
public protocol CSVRow {
    /**
     Creates a new instance from an array of CSV field strings.
     
     Implementations should validate the input and return `nil` if the fields
     cannot be parsed into a valid instance.
     
     - Parameter fields: An array of string values representing the CSV fields.
     - Returns: A new instance if parsing succeeds, or `nil` if the fields are
       invalid.
     */
    init?(from fields: [String])

    /**
     Converts this instance to an array of CSV field strings.
     
     The returned array should contain string representations of all fields
     in the correct order for CSV output.
     
     - Returns: An array of string values representing the CSV fields.
     */
    func toCSVRow() -> [String]
}
