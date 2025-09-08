import MacroToolkit
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct CSVRowBuilderMacro: MemberMacro, ExtensionMacro, MemberAttributeMacro {

    public static func expansion(
        of _: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo _: [TypeSyntax],
        in _: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Get the struct declaration
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw MacroError("@CSVRowBuilder can only be applied to structs")
        }

        // Find all properties marked with @Field
        let fieldProperties = structDecl.memberBlock.members.compactMap { member -> (name: String, type: TypeSyntax, isOptional: Bool)? in
            guard let varDecl = member.decl.as(VariableDeclSyntax.self),
                  let binding = varDecl.bindings.first,
                  let identifier = binding.pattern.as(IdentifierPatternSyntax.self),
                  let typeAnnotation = binding.typeAnnotation?.type else {
                return nil
            }

            // Check if property has @Field attribute
            let hasFieldAttribute = varDecl.attributes.contains { attribute in
                guard case .attribute(let attr) = attribute,
                      let identifierType = attr.attributeName.as(IdentifierTypeSyntax.self) else {
                    return false
                }
                return identifierType.name.text == "Field"
            }

            guard hasFieldAttribute else { return nil }

            // Check if type is optional
            let isOptional = typeAnnotation.is(OptionalTypeSyntax.self) ||
                           typeAnnotation.description.hasSuffix("?")

            return (name: identifier.identifier.text, type: typeAnnotation, isOptional: isOptional)
        }

        // Generate init?(from fields: [String])
        let initMethod = generateInitializer(for: fieldProperties)

        // Generate func toCSVRow() -> [String]
        let toCSVRowMethod = generateToCSVRow(for: fieldProperties)

        return [
            DeclSyntax(initMethod),
            DeclSyntax(toCSVRowMethod)
        ]
    }

    public static func expansion(
        of _: AttributeSyntax,
        attachedTo _: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo _: [TypeSyntax],
        in _: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        let conformanceExtension = try ExtensionDeclSyntax("extension \(type): CSVRow {}")
        return [conformanceExtension]
    }

    public static func expansion(
        of _: AttributeSyntax,
        attachedTo _: some DeclGroupSyntax,
        providingAttributesFor _: some DeclSyntaxProtocol,
        in _: some MacroExpansionContext
    ) throws -> [AttributeSyntax] {
        return []
    }

    private static func generateInitializer(for fields: [(name: String, type: TypeSyntax, isOptional: Bool)]) -> InitializerDeclSyntax {
        let parameters = FunctionParameterClauseSyntax {
            FunctionParameterSyntax(
                firstName: "from",
                secondName: "fields",
                type: ArrayTypeSyntax(element: IdentifierTypeSyntax(name: "String"))
            )
        }

        // Build the code block
        let codeBlock = CodeBlockSyntax {
            // Add guard for field count (only if we have non-optional fields)
            let requiredFieldCount = fields.filter { !$0.isOptional }.count
            if requiredFieldCount > 0 {
                "guard fields.count >= \(raw: requiredFieldCount) else { return nil }"
            }

            // Parse each field
            for (index, field) in fields.enumerated() {
                if field.isOptional {
                    // For optional fields
                    let baseType = String(field.type.description.dropLast())  // Remove the ?
                    "let \(raw: field.name): \(raw: field.type) = fields.count > \(raw: index) && !fields[\(raw: index)].isEmpty ? \(raw: baseType)(csvString: fields[\(raw: index)]) : nil"
                } else {
                    // For required fields
                    "guard let \(raw: field.name) = \(raw: field.type)(csvString: fields[\(raw: index)]) else { return nil }"
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

    private static func generateToCSVRow(for fields: [(name: String, type: TypeSyntax, isOptional: Bool)]) -> FunctionDeclSyntax {
        let fieldExpressions = fields.map { field in
            if field.isOptional {
                return "\(field.name)?.csvString ?? \"\""
            }
            return "\(field.name).csvString"
        }

        let arrayLiteral = "[" + fieldExpressions.joined(separator: ", ") + "]"

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
                "return \(raw: arrayLiteral)"
            }
        )
    }
}

struct MacroError: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}
