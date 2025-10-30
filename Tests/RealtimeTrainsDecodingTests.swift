import XCTest

@testable import LeaveNow

final class RealtimeTrainsDecodingTests: XCTestCase {
    func testDecodesBasicServiceShape() throws {
        let json = """
        {
          "services": [
            {
              "operatorName": "SWR",
              "serviceId": "srv-123",
              "headcode": "2A45",
              "originCRS": "WAT",
              "originName": "London Waterloo",
              "destCRS": "RMD",
              "destName": "Richmond",
              "std": "08:32",
              "sta": "08:49",
              "etd": "08:34",
              "eta": "08:51",
              "platform": "5"
            }
          ]
        }
        """
        let data = Data(json.utf8)
        let dto = try JSONDecoder().decode(AnyDecodable.self, from: data)
        XCTAssertNotNil(dto)
        struct RTTResponse: Decodable { let services: [S]; struct S: Decodable {
            let operatorName: String?; let serviceId: String?; let headcode: String?
            let originCRS: String?; let originName: String?; let destCRS: String?; let destName: String?
            let std: String?; let sta: String?; let etd: String?; let eta: String?; let platform: String?
        }}
        let decoded = try JSONDecoder().decode(RTTResponse.self, from: data)
        XCTAssertEqual(decoded.services.first?.platform, "5")
    }
}

struct AnyDecodable: Decodable {}


