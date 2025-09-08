@testable import StreamingCSV
import Testing

@Suite("Large File Buffer Tests")
struct LargeFileBufferTest {

    @Test
    func testLargeCSVWithSmallBuffer() async throws {
        // Create a large CSV that simulates the SwiftAirmen data
        // This should trigger the same bug that creates malformed IDs
        var csvLines: [String] = []

        // Add header
        csvLines.append("UNIQUE ID,FIRST NAME,LAST NAME,CERT,TYPE,LEVEL,EXPDATE,RATING1,RATING2,RATING3")

        // Add 1000 rows to simulate real data size
        for i in 1...1000 {
            let id = String(format: "A%07d", i)
            let firstName = "FIRST\(i)"
            let lastName = "LAST\(i)"
            let cert = "P"
            let type = "PP-ASEL"
            let level = i.isMultiple(of: 3) ? "ATP" : "COM"
            let expDate = "012025"
            let rating1 = i.isMultiple(of: 2) ? "A/ASEL" : ""
            let rating2 = i.isMultiple(of: 3) ? "C/AMEL" : ""
            let rating3 = i.isMultiple(of: 5) ? "P/GL" : ""

            csvLines.append("\(id),\(firstName),\(lastName),\(cert),\(type),\(level),\(expDate),\(rating1),\(rating2),\(rating3)")
        }

        // Add a specific row that might trigger issues
        csvLines.append("A0046345,BILLY VICTOR,ANTON,P,PP-ASEL,COM,072018,,,")
        csvLines.append("A0104644,ERIC,DAYRELL BATE,P,PP-ASEL,ATP,012025,A/ASEL,C/AMEL,P/GL")

        let csvContent = csvLines.joined(separator: "\r\n") + "\r\n"
        let data = csvContent.data(using: .utf8)!

        // Use a small buffer size to trigger boundary issues
        let reader = StreamingCSVReader(
            data: data,
            bufferSize: 64  // Very small buffer
        )

        var rowCount = 0
        var malformedIDs: [String] = []
        var billyVictorFound = false
        var ericDayrellFound = false

        while let row = try await reader.readRow() {
            rowCount += 1

            if rowCount > 1 {  // Skip header
                let id = row[0]
                let firstName = row[1]
                let lastName = row[2]

                // Check for malformed IDs
                if id.count < 3 || !id.starts(with: "A") {
                    malformedIDs.append("Row \(rowCount): ID='\(id)' FirstName='\(firstName)' LastName='\(lastName)'")
                }

                // Check for specific people
                if firstName == "BILLY VICTOR" && lastName == "ANTON" {
                    billyVictorFound = true
                    #expect(id == "A0046345")
                }

                if firstName == "ERIC" && lastName == "DAYRELL BATE" {
                    ericDayrellFound = true
                    #expect(id == "A0104644")
                }

                // Check for fragments that shouldn't be IDs
                if ["N", "ON", "L", "ER", "RD", "R", "A", "AL", "RT", "P", "D", "TT", "T", "F"].contains(id) {
                    malformedIDs.append("Fragment as ID: '\(id)' at row \(rowCount)")
                }
            }
        }

        #expect(rowCount == 1003)
        #expect(malformedIDs.isEmpty)
        #expect(billyVictorFound)
        #expect(ericDayrellFound)
    }

    @Test
    func testBufferBoundaryAtSpecificPositions() async throws {
        // Test specific buffer positions that might cause issues
        // This tests when the buffer boundary falls in the middle of an ID or name

        // Create a CSV where we know exactly where each byte is
        let csvContent = """
        ID,NAME,VAL\r
        A0001,JOHN,100\r
        A0002,BILLY,200\r
        A0003,VICTOR,300\r
        A0004,ANTON,400\r
        """

        let data = csvContent.data(using: .utf8)!

        // Calculate where the buffer might split
        // Header is 12 bytes: "ID,NAME,VAL\r\n"
        // Each data row is about 15-16 bytes

        // Test with buffer size that splits in middle of "VICTOR"
        let reader = StreamingCSVReader(
            data: data,
            bufferSize: 42  // Should split around "VIC|TOR"
        )

        var rows: [[String]] = []
        while let row = try await reader.readRow() {
            rows.append(row)
        }

        #expect(rows.count == 5)

        // Verify all rows are intact
        #expect(rows[0] == ["ID", "NAME", "VAL"])
        #expect(rows[1] == ["A0001", "JOHN", "100"])
        #expect(rows[2] == ["A0002", "BILLY", "200"])
        #expect(rows[3] == ["A0003", "VICTOR", "300"])
        #expect(rows[4] == ["A0004", "ANTON", "400"])

        // Make sure no fragments appear
        for row in rows {
            for field in row {
                #expect(!["VIC", "TOR", "AN", "TON", "IL", "LY"].contains(field))
            }
        }
    }
}
