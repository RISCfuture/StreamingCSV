import Foundation

/**
 A macro that automatically synthesizes ``CSVRow`` conformance for a struct.
 
 `@CSVRowBuilder` generates the required `init?(from:)` and `toCSVRow()` methods
 based on properties marked with ``Field()``. This eliminates boilerplate code
 for CSV serialization and deserialization.
 
 ## Usage
 Apply `@CSVRowBuilder` to a struct and mark the CSV fields with `@Field`:
 
 ```swift
 @CSVRowBuilder
 struct Person {
     @Field var name: String
     @Field var age: Int
     @Field var city: String
     @Field var email: String?
 }
 ```
 
 ## Generated Code

 The macro generates:

 - `init?(from fields: [String])` - Parses fields in declaration order
 - `func toCSVRow() -> [String]` - Serializes fields in declaration order
 - `CSVRow` protocol conformance
 
 ## Field Types

 Fields must conform to ``CSVCodable``. Optional fields are handled gracefully:
 - When parsing: Empty strings become `nil` for optional fields
 - When serializing: `nil` values become empty strings
 
 ## Preserving Custom Initializers

 The macro preserves any custom initializers you define. The generated
 `init?(from:)` calls your memberwise initializer internally:
 
 ```swift
 @CSVRowBuilder
 struct Product {
     @Field var id: Int
     @Field var name: String
     @Field var price: Double
     
     // This initializer is preserved
     init(id: Int, name: String, price: Double) {
         self.id = id
         self.name = name
         self.price = price * 1.1  // Apply markup
     }
 }
 ```
 */
@attached(member, names: named(init(from:)), named(toCSVRow))
@attached(extension, conformances: CSVRow)
public macro CSVRowBuilder() = #externalMacro(module: "StreamingCSVMacros", type: "CSVRowBuilderMacro")

/**
 Marks a struct property for inclusion in CSV serialization.
 
 Properties marked with `@Field` are included in the CSV row when using the
 ``CSVRowBuilder()`` macro. Fields are processed in the order they appear in the
 struct declaration.

 ## Requirements

 - The property type must conform to ``CSVCodable``
 - The property must be a stored property (not computed)
 - The property must be declared with `var` (not `let`)
 
 ## Example

 ```swift
 @CSVRowBuilder
 struct Employee {
     @Field var id: Int
     @Field var name: String
     @Field var department: String
     @Field var salary: Double?
     
     var internalNotes: String  // Not included in CSV
 }
 ```
 
 ## Optional Fields

 Optional fields are handled specially:

 - Empty CSV values are decoded as `nil`
 - `nil` values are encoded as empty strings
 */
@attached(peer)
public macro Field() = #externalMacro(module: "StreamingCSVMacros", type: "FieldMacro")
