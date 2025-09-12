import MacroToolkit
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct CSVRowEncoderBuilderMacro: MemberMacro, ExtensionMacro, MemberAttributeMacro {

    public static func expansion(
        of _: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo _: [TypeSyntax],
        in _: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Get the struct declaration
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw MacroError("@CSVRowEncoderBuilder can only be applied to structs")
        }

        // Extract fields using shared helper
        let fields = try FieldExtractor.extractFields(from: structDecl)

        // Generate func toCSVRow() -> [String] using shared helper
        let toCSVRowMethod = ToCSVRowGenerator.generateToCSVRow(for: fields)

        return [DeclSyntax(toCSVRowMethod)]
    }

    public static func expansion(
        of _: AttributeSyntax,
        attachedTo _: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo _: [TypeSyntax],
        in _: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        let conformanceExtension = try ExtensionDeclSyntax("extension \(type): CSVEncodableRow {}")
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
}
