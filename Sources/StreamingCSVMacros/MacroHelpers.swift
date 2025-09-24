import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// MARK: - Field Information

struct FieldInfo {
  let isArray: Bool
  let count: Int?
  let name: String
  let type: TypeSyntax
  let elementType: TypeSyntax?
  let isOptional: Bool
}

// MARK: - Field Extraction

enum FieldExtractor {
  static func extractFields(from structDecl: StructDeclSyntax) throws -> [FieldInfo] {
    var allFields: [FieldInfo] = []

    for member in structDecl.memberBlock.members {
      guard let varDecl = member.decl.as(VariableDeclSyntax.self),
        let binding = varDecl.bindings.first,
        let identifier = binding.pattern.as(IdentifierPatternSyntax.self),
        let typeAnnotation = binding.typeAnnotation?.type
      else {
        continue
      }

      let name = identifier.identifier.text

      // Check for @Field
      let hasFieldAttribute = varDecl.attributes.contains { attribute in
        guard case .attribute(let attr) = attribute,
          let identifierType = attr.attributeName.as(IdentifierTypeSyntax.self)
        else {
          return false
        }
        return identifierType.name.text == "Field"
      }

      // Check for @Fields
      var hasFieldsAttribute = false
      var fieldsCount: Int?

      for attribute in varDecl.attributes {
        guard case .attribute(let attr) = attribute,
          let identifierType = attr.attributeName.as(IdentifierTypeSyntax.self),
          identifierType.name.text == "Fields"
        else {
          continue
        }

        hasFieldsAttribute = true

        // Check for parameter (e.g., @Fields(11))
        if let args = attr.arguments,
          case .argumentList(let argList) = args,
          let firstArg = argList.first,
          let intLiteral = firstArg.expression.as(IntegerLiteralExprSyntax.self)
        {
          fieldsCount = Int(intLiteral.literal.text)
        }
        break
      }

      if hasFieldAttribute {
        let isOptional =
          typeAnnotation.is(OptionalTypeSyntax.self) || typeAnnotation.description.hasSuffix("?")
        allFields.append(
          FieldInfo(
            isArray: false,
            count: nil,
            name: name,
            type: typeAnnotation,
            elementType: nil,
            isOptional: isOptional
          )
        )
      } else if hasFieldsAttribute {
        // Extract element type from array
        var elementType: TypeSyntax?
        if let arrayType = typeAnnotation.as(ArrayTypeSyntax.self) {
          elementType = arrayType.element
        } else {
          // Handle [Type] shorthand
          let typeStr = typeAnnotation.description.trimmingCharacters(in: .whitespaces)
          if typeStr.hasPrefix("[") && typeStr.hasSuffix("]") {
            let elementTypeStr = String(typeStr.dropFirst().dropLast()).trimmingCharacters(
              in: .whitespaces
            )
            elementType = TypeSyntax(IdentifierTypeSyntax(name: .identifier(elementTypeStr)))
          }
        }

        guard elementType != nil else {
          throw MacroError("@Fields must be applied to an array property")
        }

        allFields.append(
          FieldInfo(
            isArray: true,
            count: fieldsCount,
            name: name,
            type: typeAnnotation,
            elementType: elementType,
            isOptional: false
          )
        )
      }
    }

    // Validate that only one parameterless @Fields exists and it's last
    let parameterlessFields = allFields.filter { $0.isArray && $0.count == nil }
    if parameterlessFields.count > 1 {
      throw MacroError("Only one parameterless @Fields is allowed")
    }
    if !parameterlessFields.isEmpty && allFields.last?.name != parameterlessFields[0].name {
      throw MacroError("Parameterless @Fields must be the last field")
    }

    return allFields
  }
}

// MARK: - Code Generation Helpers

enum InitializerGenerator {
  static func generateInitializer(for fields: [FieldInfo], protocolType _: String = "CSVDecodable")
    -> InitializerDeclSyntax
  {
    let parameters = FunctionParameterClauseSyntax {
      FunctionParameterSyntax(
        firstName: "from",
        secondName: "fields",
        type: ArrayTypeSyntax(element: IdentifierTypeSyntax(name: "String"))
      )
    }

    // Calculate minimum required field count
    let requiredSingleFields = fields.filter { !$0.isArray && !$0.isOptional }.count

    // Build the code block
    let codeBlock = CodeBlockSyntax {
      // We only need to check minimum if there are required single fields
      if requiredSingleFields > 0 {
        "guard fields.count >= \(raw: requiredSingleFields) else { return nil }"
      }

      // Track current field index
      "var fieldIndex = 0"

      // Parse each field
      for field in fields {
        if field.isArray {
          // Handle @Fields
          if let count = field.count {
            // @Fields(n) - collect exactly n fields
            "var \(raw: field.name): [\(raw: field.elementType!)] = []"
            "for _ in 0..<\(raw: count) {"
            "    if fieldIndex < fields.count {"
            "        if let element = \(raw: field.elementType!)(csvString: fields[fieldIndex]) {"
            "            \(raw: field.name).append(element)"
            "        }"
            "        fieldIndex += 1"
            "    }"
            "}"
          } else {
            // @Fields - collect all remaining fields
            "var \(raw: field.name): [\(raw: field.elementType!)] = []"
            "while fieldIndex < fields.count {"
            "    if let element = \(raw: field.elementType!)(csvString: fields[fieldIndex]) {"
            "        \(raw: field.name).append(element)"
            "    }"
            "    fieldIndex += 1"
            "}"
          }
        } else {
          // Handle @Field
          if field.isOptional {
            // For optional fields
            let baseType = String(field.type.description.dropLast())  // Remove the ?
            "let \(raw: field.name): \(raw: field.type) = fieldIndex < fields.count && !fields[fieldIndex].isEmpty ? \(raw: baseType)(csvString: fields[fieldIndex]) : nil"
            "fieldIndex += 1"
          } else {
            // For required fields
            "guard fieldIndex < fields.count else { return nil }"
            "guard let \(raw: field.name) = \(raw: field.type)(csvString: fields[fieldIndex]) else { return nil }"
            "fieldIndex += 1"
          }
        }
      }

      // Initialize self by directly assigning to properties
      for field in fields {
        "self.\(raw: field.name) = \(raw: field.name)"
      }
    }

    return InitializerDeclSyntax(
      modifiers: [DeclModifierSyntax(name: .keyword(.public))],
      optionalMark: TokenSyntax.postfixQuestionMarkToken(),
      signature: FunctionSignatureSyntax(parameterClause: parameters),
      body: codeBlock
    )
  }
}

enum ToCSVRowGenerator {
  static func generateToCSVRow(for fields: [FieldInfo]) -> FunctionDeclSyntax {
    return FunctionDeclSyntax(
      modifiers: [DeclModifierSyntax(name: .keyword(.public))],
      name: "toCSVRow",
      signature: FunctionSignatureSyntax(
        parameterClause: FunctionParameterClauseSyntax(parameters: []),
        returnClause: ReturnClauseSyntax(
          type: ArrayTypeSyntax(element: IdentifierTypeSyntax(name: "String"))
        )
      ),
      body: CodeBlockSyntax {
        "var result: [String] = []"

        for field in fields {
          if field.isArray {
            if let count = field.count {
              // @Fields(n) - output exactly n fields with padding
              "// Add \(raw: field.name) with padding to \(raw: count) fields"
              "for i in 0..<\(raw: count) {"
              "    if i < \(raw: field.name).count {"
              "        result.append(\(raw: field.name)[i].csvString)"
              "    } else {"
              "        result.append(\"\")"
              "    }"
              "}"
            } else {
              // @Fields - output all elements without padding
              "for element in \(raw: field.name) {"
              "    result.append(element.csvString)"
              "}"
            }
          } else {
            // @Field
            if field.isOptional {
              "result.append(\(raw: field.name)?.csvString ?? \"\")"
            } else {
              "result.append(\(raw: field.name).csvString)"
            }
          }
        }

        "return result"
      }
    )
  }
}

// MARK: - Error

public struct MacroError: Error, CustomStringConvertible {
  public let description: String

  public init(_ description: String) {
    self.description = description
  }
}
