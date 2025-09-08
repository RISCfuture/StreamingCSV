@testable import StreamingCSV
import Testing

@Suite("Malformed ID Tests")
struct MalformedIDTest {

    @Test
    func testNoMalformedIDsFromBufferSplits() async throws {
        // Create CSV content that when split at certain buffer boundaries
        // might create malformed rows
        // The bug appears to happen when a row is split across buffers

        // Create a CSV where buffer boundaries might fall in the middle of rows
        let csvContent = """
        UNIQUE ID,FIRST NAME,LAST NAME
        A0104644,ERIC,DAYRELL
        A0104645,JOHN,SMITH
        A0104646,BILLY,VICTOR
        A0104647,ANTON,JOHNSON
        A0104648,MARY,WILLIAMS
        """

        let data = csvContent.data(using: .utf8)!

        // Test with various buffer sizes that might split rows
        let bufferSizes = [10, 15, 20, 25, 30, 35, 40, 45, 50]

        for bufferSize in bufferSizes {
            let reader = StreamingCSVReader(
                data: data,
                bufferSize: bufferSize
            )

            var rows: [[String]] = []
            while let row = try await reader.readRow() {
                rows.append(row)
            }

            #expect(rows.count == 6)

            // Check no malformed IDs
            for (index, row) in rows.enumerated() {
                if index == 0 { continue } // Skip header

                let id = row[0]
                let firstName = row[1]
                let lastName = row[2]

                // IDs should all start with A and be 8 characters
                #expect(id.count == 8)
                #expect(id.starts(with: "A"))

                // Names should not be fragments
                #expect(firstName.count > 1)
                #expect(lastName.count > 1)

                // Check for specific known fragments that shouldn't appear as IDs
                #expect(id != "N")
                #expect(id != "ON")
                #expect(id != "L")
                #expect(id != "ER")
                #expect(id != "RD")
                #expect(id != "5")
            }
        }
    }

    @Test
    func testSpecificBufferSplitScenario() async throws {
        // Test a specific scenario where "BILLY,VICTOR,ANTON" might be misinterpreted
        // This simulates what might happen if buffer boundary falls after "BILLY,VICTOR,AN"
        // and "TON" starts the next buffer

        let csvContent = """
        ID,NAME,VALUE
        1,BILLY,100
        2,VICTOR,200
        3,ANTON,300
        """

        let data = csvContent.data(using: .utf8)!

        // Use a buffer size that might split "ANTON" 
        let reader = StreamingCSVReader(
            data: data,
            bufferSize: 33  // Calculated to potentially split in problematic places
        )

        var rows: [[String]] = []
        while let row = try await reader.readRow() {
            rows.append(row)
        }

        #expect(rows.count == 4)

        // Verify all rows are complete
        #expect(rows[0] == ["ID", "NAME", "VALUE"])
        #expect(rows[1] == ["1", "BILLY", "100"])
        #expect(rows[2] == ["2", "VICTOR", "200"])
        #expect(rows[3] == ["3", "ANTON", "300"])

        // Make sure no fragments appear as separate rows
        for row in rows {
            for field in row {
                // Check that no field is a known fragment
                #expect(field != "ON")
                #expect(field != "TON")
                #expect(field != "OR")
                #expect(field != "TOR")
            }
        }
    }

    @Test
    func testLargeCSVWithSmallBuffer() async throws {
        // Test with a larger dataset and very small buffer
        var csvLines = ["ID,FIRST,LAST,CITY,STATE"]

        // Add 100 rows
        for i in 1...100 {
            csvLines.append("A\(String(format: "%07d", i)),FIRST\(i),LAST\(i),CITY\(i),ST")
        }

        let csvContent = csvLines.joined(separator: "\n")
        let data = csvContent.data(using: .utf8)!

        // Very small buffer to stress test
        let reader = StreamingCSVReader(
            data: data,
            bufferSize: 16
        )

        var rowCount = 0
        var malformedIDs: [String] = []

        while let row = try await reader.readRow() {
            rowCount += 1

            if rowCount > 1 {  // Skip header
                let id = row[0]

                // Check for malformed IDs
                if id.count != 8 || !id.starts(with: "A") {
                    malformedIDs.append(id)
                }
            }
        }

        #expect(rowCount == 101)
        #expect(malformedIDs.isEmpty)
    }
}
