@testable import StreamingCSV
import Testing

@Suite("Buffer Boundary Tests")
struct BufferBoundaryTests {

    @Test
    func testBufferBoundaryParsing() async throws {
        // Create a CSV with rows that will span buffer boundaries
        // Use a small buffer size to force boundary issues
        let csvContent = """
        uniqueID,firstName,lastName,middleName,suffix,city,state,country
        A0104644,ERIC,DAYRELL,BATE,,SEATTLE,WA,USA
        A0104645,JOHN,SMITH,DOE,,PORTLAND,OR,USA
        A0104646,JANE,WILLIAMS,ANN,,DENVER,CO,USA
        A0104647,ROBERT,JOHNSON,MICHAEL,,PHOENIX,AZ,USA
        A0104648,MARY,DAVIS,ELIZABETH,,LAS VEGAS,NV,USA
        A0104649,JAMES,BROWN,WILLIAM,,SAN FRANCISCO,CA,USA
        A0104650,PATRICIA,JONES,MARIE,,LOS ANGELES,CA,USA
        """

        let data = csvContent.data(using: .utf8)!

        // Test with very small buffer to force boundary conditions
        let reader = StreamingCSVReader(
            data: data,
            bufferSize: 32  // Small buffer to force multiple reads
        )

        var rows: [[String]] = []
        while let row = try await reader.readRow() {
            rows.append(row)
        }

        // Should have 8 rows (header + 7 data rows)
        #expect(rows.count == 8)

        // Verify header
        #expect(rows[0] == ["uniqueID", "firstName", "lastName", "middleName", "suffix", "city", "state", "country"])

        // Verify first data row
        #expect(rows[1][0] == "A0104644")
        #expect(rows[1][1] == "ERIC")
        #expect(rows[1][2] == "DAYRELL")

        // Verify no malformed IDs (single digits, fragments)
        for (index, row) in rows.enumerated() {
            if index == 0 { continue } // Skip header
            let id = row[0]
            #expect(id.count > 2)
            #expect(id.starts(with: "A"))
        }
    }

    @Test
    func testBufferBoundaryWithQuotedFields() async throws {
        // Test with quoted fields that might span boundaries
        let csvContent = """
        id,name,description
        1,"John Smith","This is a long description that might span buffer boundaries"
        2,"Jane Doe","Another description with, comma inside"
        3,"Bob Johnson","Description with ""escaped quotes"" inside"
        """

        let data = csvContent.data(using: .utf8)!

        // Very small buffer to force boundary issues
        let reader = StreamingCSVReader(
            data: data,
            bufferSize: 20
        )

        var rows: [[String]] = []
        while let row = try await reader.readRow() {
            rows.append(row)
        }

        #expect(rows.count == 4)

        // Verify data integrity
        #expect(rows[1][0] == "1")
        #expect(rows[1][1] == "John Smith")
        #expect(rows[1][2] == "This is a long description that might span buffer boundaries")

        #expect(rows[2][2] == "Another description with, comma inside")
        #expect(rows[3][2] == "Description with \"escaped quotes\" inside")
    }

    @Test
    func testBufferBoundaryWithVariousLineSizes() async throws {
        // Create rows of varying lengths to test different boundary conditions
        var csvLines: [String] = ["id,data"]

        // Add rows of increasing size
        for i in 1...10 {
            let data = String(repeating: "X", count: i * 10)
            csvLines.append("\(i),\"\(data)\"")
        }

        let csvContent = csvLines.joined(separator: "\n")
        let data = csvContent.data(using: .utf8)!

        let reader = StreamingCSVReader(
            data: data,
            bufferSize: 50  // Buffer smaller than some rows
        )

        var rows: [[String]] = []
        while let row = try await reader.readRow() {
            rows.append(row)
        }

        #expect(rows.count == 11)

        // Verify each row
        for i in 1...10 {
            let row = rows[i]
            #expect(row[0] == "\(i)")
            #expect(row[1].count == i * 10)
        }
    }

    @Test
    func testBufferBoundaryAtExactRowEnd() async throws {
        // Test when buffer boundary falls exactly at row end
        // Each row is exactly 16 bytes (including newline)
        let csvContent = """
        id,name,val
        1,John,100
        2,Jane,200
        3,Bob,300
        """

        let data = csvContent.data(using: .utf8)!

        // Buffer size that might align with row boundaries
        let reader = StreamingCSVReader(
            data: data,
            bufferSize: 16
        )

        var rows: [[String]] = []
        while let row = try await reader.readRow() {
            rows.append(row)
        }

        #expect(rows.count == 4)
        #expect(rows[0] == ["id", "name", "val"])
        #expect(rows[1] == ["1", "John", "100"])
        #expect(rows[2] == ["2", "Jane", "200"])
        #expect(rows[3] == ["3", "Bob", "300"])
    }

    @Test
    func testRealWorldCSVParsing() async throws {
        // Simulate the real data format from SwiftAirmen
        let csvContent = """
        UNIQUE ID,FIRST NAME,LAST NAME,CERT,TYPE,LEVEL,EXPDATE,RATING
        A0104644,ERIC,DAYRELL,P,PP-ASEL,ATR,102025,EX-H,L,M-COMM
        A0104645,JOHN,SMITH,P,PP-AMEL,COM,122025,H,SEA
        A0104646,JANE,DOE,P,PP-ASEL,PVT,012026,
        A0104647,ROBERT,JOHNSON,A,A,AMT,032026,
        A0104648,MARY,WILLIAMS,P,PP-GLIDER,COM,042026,G
        """

        let data = csvContent.data(using: .utf8)!

        // Use small buffer to test boundary conditions
        let reader = StreamingCSVReader(
            data: data,
            bufferSize: 40  // Force multiple buffer fills
        )

        var rows: [[String]] = []
        var rowCount = 0
        while let row = try await reader.readRow() {
            rows.append(row)
            rowCount += 1

            // Verify no single-character IDs
            if rowCount > 1 {  // Skip header
                let id = row[0]
                #expect(id.count > 2)
            }
        }

        #expect(rows.count == 6)

        // Verify specific IDs
        #expect(rows[1][0] == "A0104644")
        #expect(rows[1][1] == "ERIC")
        #expect(rows[1][2] == "DAYRELL")

        #expect(rows[2][0] == "A0104645")
        #expect(rows[3][0] == "A0104646")
        #expect(rows[4][0] == "A0104647")
        #expect(rows[5][0] == "A0104648")
    }
}
