import Foundation

/**
 A type that can be decoded from a CSV string representation.
 
 Types conforming to `CSVDecodable` can be initialized from CSV field values.
 The protocol requires a failable initializer that attempts to parse a string
 value.

 ## Conforming to CSVDecodable

 To add `CSVDecodable` conformance to your custom types, implement the failable
 initializer:

 ```swift
 struct ProductCode: CSVDecodable {
     let prefix: String
     let number: Int
     
     init?(csvString: String) {
         let parts = csvString.split(separator: "-")
         guard parts.count == 2,
               let num = Int(parts[1]) else {
             return nil
         }
         self.prefix = String(parts[0])
         self.number = num
     }
 }
 ```
 */
public protocol CSVDecodable {

    /**
     Creates a new instance by decoding from a CSV string value.
     
     - Parameter csvString: The CSV field value to decode.
     - Returns: A new instance if decoding succeeds, or `nil` if the string
       cannot be parsed.
     */
    init?(csvString: String)
}

/**
 A type that can be encoded to a CSV string representation.
 
 Types conforming to `CSVEncodable` can be serialized as CSV field values.
 The protocol requires a computed property that returns the string
 representation suitable for CSV output.

 ## Conforming to CSVEncodable
 To add `CSVEncodable` conformance to your custom types, implement the
 ``csvString`` property:

 ```swift
 struct ProductCode: CSVEncodable {
     let prefix: String
     let number: Int
     
     var csvString: String {
         "\(prefix)-\(number)"
     }
 }
 ```
 */
public protocol CSVEncodable {

    /**
     The CSV string representation of this value.
     
     This property should return a string that can be used as a field value in
     CSV output. The string will be automatically quoted and escaped as needed
     by the CSV writer.
     */
    var csvString: String { get }
}

/**
 A type that can be both encoded to and decoded from CSV string representations.
 
 `CSVCodable` is a type alias combining ``CSVEncodable`` and ``CSVDecodable``.
 Types that conform to both protocols can be used for both reading and writing
 CSV data.

 ## Standard Conformances

 The following standard library types conform to `CSVCodable`:

 - `String`
 - `Int`, `Int8`, `Int16`, `Int32`, `Int64`
 - `UInt`, `UInt8`, `UInt16`, `UInt32`, `UInt64`
 - `Float`, `Double`
 - `Bool`
 - `Data` (Base64 encoded)
 - `Optional` (where `Wrapped: CSVCodable`)
 */
public typealias CSVCodable = CSVDecodable & CSVEncodable

extension CSVEncodable {

    /**
     Encodes this value into a mutable array of CSV fields.
     
     This is a convenience method that appends the ``csvString`` representation
     to the provided array.
     
     - Parameter fields: The array to append the encoded value to.
     */
    func encode(into fields: inout [String]) {
        fields.append(csvString)
    }
}
