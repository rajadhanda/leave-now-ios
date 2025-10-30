import Foundation

struct RealtimeTrainsService: NationalRailService {
    private let session: URLSession
    private let baseURL: URL
    private let apiKey: String

    init?(session: URLSession = .shared) {
        guard let baseURL = Secrets.realtimeTrainsBaseURL,
              let apiKey = Secrets.realtimeTrainsApiKey else { return nil }
        self.session = session
        self.baseURL = baseURL
        self.apiKey = apiKey
    }

    func nextServices(from originCRS: String, to destCRS: String, around when: Date, limit: Int) async throws -> [RailLegMeta] {
        var comps = URLComponents(url: baseURL.appendingPathComponent("/v1/next"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            .init(name: "from", value: originCRS),
            .init(name: "to", value: destCRS),
            .init(name: "at", value: iso8601Minute(when)),
            .init(name: "limit", value: String(limit))
        ]
        var req = URLRequest(url: comps.url!)
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let dto = try JSONDecoder.rtt.decode(RTTResponse.self, from: data)
        return dto.services.prefix(limit).compactMap { $0.asRailLegMeta() }
    }

    private func iso8601Minute(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = .init(identifier: "en_GB")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return f.string(from: d)
    }
}

// MARK: - Tolerant decoding
private struct RTTResponse: Decodable {
    let services: [RTTService]

    struct RTTService: Decodable {
        let operatorName: String?
        let serviceId: String?
        let headcode: String?
        let originCRS: String?
        let originName: String?
        let destCRS: String?
        let destName: String?
        let std: String?
        let sta: String?
        let etd: String?
        let eta: String?
        let platform: String?

        let locationDetail: LocationDetail?
        struct LocationDetail: Decodable {
            let platform: String?
            let crs: String?
            let tiploc: String?
            let scheduledTime: String?
            let realtimeTime: String?
        }

        func asRailLegMeta() -> RailLegMeta? {
            let oCRS = originCRS ?? locationDetail?.crs
            let dCRS = destCRS ?? nil
            let oName = originName ?? "Origin"
            let dName = destName ?? "Destination"
            guard let o = oCRS, let d = dCRS else { return nil }

            guard let depPlanned = TimeParser.parse(std ?? locationDetail?.scheduledTime),
                  let arrPlanned = TimeParser.parse(sta) else { return nil }
            let depEst = TimeParser.parse(etd ?? locationDetail?.realtimeTime)
            let arrEst = TimeParser.parse(eta)
            let platformResolved = platform ?? locationDetail?.platform

            return RailLegMeta(
                operatorName: operatorName,
                serviceId: serviceId,
                headcode: headcode,
                origin: .init(crs: o, name: oName),
                destination: .init(crs: d, name: dName),
                departure: .init(plannedTime: depPlanned, estimatedTime: depEst, platform: platformResolved),
                arrival: .init(plannedTime: arrPlanned, estimatedTime: arrEst, platform: nil)
            )
        }
    }
}

private enum TimeParser {
    static func parse(_ s: String?) -> Date? {
        guard let s = s else { return nil }
        let fmts = ["HH:mm", "yyyy-MM-dd'T'HH:mm"]
        for f in fmts {
            let df = DateFormatter()
            df.locale = .init(identifier: "en_GB")
            df.dateFormat = f
            if let d = df.date(from: s) { return d }
        }
        return nil
    }
}

private extension JSONDecoder {
    static var rtt: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}


