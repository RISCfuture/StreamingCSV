import MacroToolkit
import SwiftSyntax
import SwiftSyntaxMacros

public struct FieldsMacro: PeerMacro {
  public static func expansion(
    of _: AttributeSyntax,
    providingPeersOf _: some DeclSyntaxProtocol,
    in _: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    // Fields macro is just a marker, doesn't generate any code itself
    // The CSVRowBuilder macro will look for properties marked with @Fields
    return []
  }
}
