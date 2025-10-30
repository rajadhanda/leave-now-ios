import Foundation

public struct RailStop: Equatable, Codable {
    public let crs: String
    public let name: String
}

public struct RailServiceCall: Equatable, Codable {
    public let plannedTime: Date
    public let estimatedTime: Date?
    public let platform: String?
}

public struct RailLegMeta: Equatable, Codable {
    public let operatorName: String?
    public let serviceId: String?
    public let headcode: String?
    public let origin: RailStop
    public let destination: RailStop
    public let departure: RailServiceCall
    public let arrival: RailServiceCall
}

public protocol NationalRailService {
    func nextServices(from originCRS: String, to destCRS: String, around when: Date, limit: Int) async throws -> [RailLegMeta]
}


