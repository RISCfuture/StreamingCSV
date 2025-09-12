import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct StreamingCSVMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        CSVRowBuilderMacro.self,
        CSVRowDecoderBuilderMacro.self,
        CSVRowEncoderBuilderMacro.self,
        FieldMacro.self,
        FieldsMacro.self
    ]
}
