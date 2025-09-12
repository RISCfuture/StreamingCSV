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

/**
 Marks a property to collect a fixed number of CSV fields into an array.
 
 `@Fields(n)` collects exactly n fields into the array, padding with empty strings
 on output if the array contains fewer than n elements.

 ## Requirements

 - The property must be an array type (e.g., `[String]`, `[Int]`)
 - The array element type must conform to ``CSVCodable``
 - Must be used with ``CSVRowBuilder()`` macro
 
 ## Example

 ```swift
 @CSVRowBuilder
 struct TestResult {
     @Field var studentId: String
     @Field var name: String
     @Fields(5) var scores: [Int]  // Always 5 score fields
     @Field var grade: String
 }
 
 // CSV: "001,Alice,85,90,88,92,95,A"
 // Parses to:
 // - studentId: "001"
 // - name: "Alice"
 // - scores: [85, 90, 88, 92, 95]
 // - grade: "A"
 
 // CSV: "002,Bob,78,82,,,B"  // Only 2 scores provided
 // Parses to:
 // - studentId: "002"
 // - name: "Bob"
 // - scores: [78, 82]  // Empty fields are skipped
 // - grade: "B"
 
 // When serializing back, scores will be padded:
 // Output: "002,Bob,78,82,,,B"  // Padded to 5 fields
 ```
 
 ## Behavior
 
 - **During parsing**: Collects up to n fields from the current position in the CSV row
 - **During serialization**: Outputs exactly n fields, padding with empty strings if needed
 - **Empty fields**: Empty fields in the input are skipped (not added to the array)
 
 - parameter count: The exact number of fields to collect into the array
 */
@attached(peer)
public macro Fields(_ count: Int) = #externalMacro(module: "StreamingCSVMacros", type: "FieldsMacro")

/**
 Marks a property to collect all remaining CSV fields into an array.
 
 Parameterless `@Fields` collects all remaining fields after the previous fields
 into the array. This must be the last field in your struct.

 ## Requirements

 - The property must be an array type (e.g., `[String]`, `[Int]`)
 - The array element type must conform to ``CSVCodable``
 - Only one parameterless `@Fields` is allowed per struct
 - Must be the last field in the struct
 - Must be used with ``CSVRowBuilder()`` macro
 
 ## Example

 ```swift
 @CSVRowBuilder
 struct FlexibleRecord {
     @Field var id: String
     @Field var name: String
     @Fields var tags: [String]  // Collects all remaining fields
 }
 
 // CSV: "001,Item1,tag1,tag2,tag3"
 // Parses to:
 // - id: "001"
 // - name: "Item1"
 // - tags: ["tag1", "tag2", "tag3"]
 
 // CSV: "002,Item2"  // No extra fields
 // Parses to:
 // - id: "002"
 // - name: "Item2"
 // - tags: []  // Empty array
 
 // When serializing, no padding is applied:
 // Output: "001,Item1,tag1,tag2,tag3"
 ```
 
 ## Combining Fixed and Variable Fields
 
 ```swift
 @CSVRowBuilder
 struct DataRecord {
     @Field var id: String
     @Field var type: String
     @Fields(3) var primaryValues: [Double]  // Fixed 3 slots
     @Fields var metadata: [String]          // All remaining
 }
 
 // CSV: "001,TypeA,1.5,2.5,3.5,meta1,meta2"
 // primaryValues gets [1.5, 2.5, 3.5]
 // metadata gets ["meta1", "meta2"]
 ```
 
 ## Behavior
 
 - **During parsing**: Collects all remaining fields after previous fields
 - **During serialization**: Outputs all array elements without padding
 - **Position**: Must be the last field in the struct
 */
@attached(peer)
public macro Fields() = #externalMacro(module: "StreamingCSVMacros", type: "FieldsMacro")
