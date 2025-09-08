import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct StreamingCSVMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        CSVRowBuilderMacro.self,
        FieldMacro.self
    ]
}
