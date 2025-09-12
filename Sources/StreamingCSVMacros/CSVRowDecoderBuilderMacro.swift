import MacroToolkit
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct CSVRowDecoderBuilderMacro: MemberMacro, ExtensionMacro, MemberAttributeMacro {

    public static func expansion(
        of _: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo _: [TypeSyntax],
        in _: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Get the struct declaration
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw MacroError("@CSVRowDecoderBuilder can only be applied to structs")
        }

        // Extract fields using shared helper
        let fields = try FieldExtractor.extractFields(from: structDecl)

        // Generate init?(from fields: [String]) using shared helper
        let initMethod = InitializerGenerator.generateInitializer(for: fields, protocolType: "CSVDecodable")

        return [DeclSyntax(initMethod)]
    }

    public static func expansion(
        of _: AttributeSyntax,
        attachedTo _: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo _: [TypeSyntax],
        in _: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        let conformanceExtension = try ExtensionDeclSyntax("extension \(type): CSVDecodableRow {}")
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
