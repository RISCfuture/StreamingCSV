import Foundation
@testable import StreamingCSV
import Testing

@Suite("Empty Quoted Fields")
struct EmptyQuotedFieldTests {

    @Test("Parse empty quoted fields correctly")
    func emptyQuotedFields() async throws {
        // Create test CSV with empty quoted fields
        let csvContent = """
        "field1","field2","field3","field4","field5"
        "value1","value2","","value4","value5"
        "another","row","with","empty",""
        """

        let data = csvContent.data(using: .utf8)!
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_empty.csv")
        try data.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let reader = try StreamingCSVReader(url: tempURL)

        // Read header
        let header = try #require(await reader.readRow())
        #expect(header.count == 5)

        // Read first data row
        let row1 = try #require(await reader.readRow())
        #expect(row1.count == 5, "First row should have 5 fields")
        #expect(row1[0] == "value1")
        #expect(row1[1] == "value2")
        #expect(row1[2].isEmpty, "Third field should be empty")
        #expect(row1[3] == "value4")
        #expect(row1[4] == "value5")

        // Read second data row
        let row2 = try #require(await reader.readRow())
        #expect(row2.count == 5, "Second row should have 5 fields")
        #expect(row2[4].isEmpty, "Last field should be empty")
    }

    @Test("Parse rows with trailing empty fields")
    func problematicAPTBaseRow() async throws {
        // Recreate the problematic structure from APT_BASE.csv
        // Row 126 (HEY) seems to have issues with empty quoted fields
        let csvContent = """
        "COL1","COL2","COL3","COL4","COL5","COL6","COL7","COL8","COL9","COL10"
        "2025/09/04","00329.","A","AL","OZR","FORT NOVOSEL","US","ASO","JAN","ALABAMA"
        "2025/09/04","00329.01","H","AL","HEY","FORT NOVOSEL","","","",""
        "2025/09/04","00329.03","H","AL","LOR","FORT NOVOSEL","US","ASO","JAN","ALABAMA"
        """

        let data = csvContent.data(using: .utf8)!
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_apt.csv")
        try data.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let reader = try StreamingCSVReader(url: tempURL)

        // Read header
        let header = try #require(await reader.readRow())
        #expect(header.count == 10)

        // Read all data rows
        var rowCount = 0
        var rows: [[String]] = []

        while let row = try await reader.readRow() {
            rowCount += 1
            rows.append(row)
            #expect(row.count == 10, "Row \(rowCount) should have 10 fields but has \(row.count)")
        }

        #expect(rowCount == 3, "Should read exactly 3 data rows")

        // Verify specific fields
        #expect(rows[0][4] == "OZR", "First row COL5 should be OZR")
        #expect(rows[1][4] == "HEY", "Second row COL5 should be HEY")
        #expect(rows[1][6].isEmpty, "Second row COL7 should be empty")
        #expect(rows[1][7].isEmpty, "Second row COL8 should be empty")
        #expect(rows[1][8].isEmpty, "Second row COL9 should be empty")
        #expect(rows[1][9].isEmpty, "Second row COL10 should be empty")
        #expect(rows[2][4] == "LOR", "Third row COL5 should be LOR")
    }
}
