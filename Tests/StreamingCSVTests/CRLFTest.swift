@testable import StreamingCSV
import Testing

@Suite("CRLF Line Ending Tests")
struct CRLFTest {

    @Test
    func testCRLFLineEndings() async throws {
        // Test with Windows-style CRLF line endings
        let csvContent = "ID,NAME,VALUE\r\nA001,John,100\r\nA002,Jane,200\r\nA003,Bob,300\r\n"
        let data = csvContent.data(using: .utf8)!

        let reader = StreamingCSVReader(
            data: data,
            bufferSize: 20  // Small buffer to test boundary conditions
        )

        var rows: [[String]] = []
        while let row = try await reader.readRow() {
            rows.append(row)
        }

        #expect(rows.count == 4)
        #expect(rows[0] == ["ID", "NAME", "VALUE"])
        #expect(rows[1] == ["A001", "John", "100"])
        #expect(rows[2] == ["A002", "Jane", "200"])
        #expect(rows[3] == ["A003", "Bob", "300"])
    }

    @Test
    func testCRLFAtBufferBoundary() async throws {
        // Test when CRLF falls exactly at buffer boundary
        // Each line is 15 bytes including CRLF
        let csvContent = "ID,NAME,VAL\r\n01,John,100\r\n02,Jane,200\r\n"
        let data = csvContent.data(using: .utf8)!

        // Buffer size of 14 means CRLF will often span boundaries
        let reader = StreamingCSVReader(
            data: data,
            bufferSize: 14
        )

        var rows: [[String]] = []
        while let row = try await reader.readRow() {
            rows.append(row)
        }

        #expect(rows.count == 3)
        #expect(rows[0] == ["ID", "NAME", "VAL"])
        #expect(rows[1] == ["01", "John", "100"])
        #expect(rows[2] == ["02", "Jane", "200"])
    }

    @Test
    func testMixedLineEndings() async throws {
        // Test with mixed LF and CRLF line endings
        let csvContent = "ID,NAME\nA001,John\r\nA002,Jane\nA003,Bob\r\n"
        let data = csvContent.data(using: .utf8)!

        let reader = StreamingCSVReader(
            data: data,
            bufferSize: 15
        )

        var rows: [[String]] = []
        while let row = try await reader.readRow() {
            rows.append(row)
        }

        #expect(rows.count == 4)
        #expect(rows[0] == ["ID", "NAME"])
        #expect(rows[1] == ["A001", "John"])
        #expect(rows[2] == ["A002", "Jane"])
        #expect(rows[3] == ["A003", "Bob"])
    }

    @Test
    func testRealWorldFormatWithCRLF() async throws {
        // Test the exact format from SwiftAirmen with lots of empty fields and trailing spaces
        let csvContent = """
        UNIQUE ID, FIRST NAME, LAST NAME, STREET 1, STREET 2, CITY, STATE, ZIP CODE, COUNTRY, REGION, MED CLASS, MED DATE, MED EXP DATE, BASIC MED COURSE DATE, BASIC MED CMEC DATE,\r
        A0046345,BILLY VICTOR,ANTON ,2268 ROAD II,                                 ,SATANTA,KS,67870-2302,USA,CE,3,072016,072018,20250826,20230404,\r
        A0104644,ERIC,DAYRELL BATE ,123 MAIN ST,                                 ,SEATTLE,WA,98101,USA,NW,1,012025,012027,,,\r
        """

        let data = csvContent.data(using: .utf8)!

        // Test with very small buffer to stress test
        let reader = StreamingCSVReader(
            data: data,
            bufferSize: 30
        )

        var rows: [[String]] = []
        while let row = try await reader.readRow() {
            rows.append(row)
        }

        #expect(rows.count == 3)

        // Check the header
        #expect(rows[0][0] == "UNIQUE ID")
        #expect(rows[0][1] == " FIRST NAME")
        #expect(rows[0][2] == " LAST NAME")

        // Check BILLY VICTOR ANTON row
        #expect(rows[1][0] == "A0046345")
        #expect(rows[1][1] == "BILLY VICTOR")
        #expect(rows[1][2] == "ANTON ")

        // Check ERIC DAYRELL BATE row
        #expect(rows[2][0] == "A0104644")
        #expect(rows[2][1] == "ERIC")
        #expect(rows[2][2] == "DAYRELL BATE ")
    }

    @Test
    func testCRLFWithQuotedFields() async throws {
        // Test CRLF with quoted fields that may contain line breaks
        let csvContent = "ID,DESC\r\n1,\"Line 1\nLine 2\"\r\n2,\"Normal\"\r\n"
        let data = csvContent.data(using: .utf8)!

        let reader = StreamingCSVReader(
            data: data,
            bufferSize: 15
        )

        var rows: [[String]] = []
        while let row = try await reader.readRow() {
            rows.append(row)
        }

        #expect(rows.count == 3)
        #expect(rows[0] == ["ID", "DESC"])
        #expect(rows[1] == ["1", "Line 1\nLine 2"])  // Quoted field with embedded LF
        #expect(rows[2] == ["2", "Normal"])
    }
}
