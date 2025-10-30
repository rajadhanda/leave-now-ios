import Foundation

enum DemoConfig {
    // Update these for local testing; used by LeaveNowView.refresh()
    static let originPostcode: String = "EC2M 2QS" // Near Liverpool Street
    static let destinationPostcode: String = "MK9 1LA" // Milton Keynes Central area

    // Fast local mapping to avoid slow geocoder lookups during demo
    static func coords(for postcode: String) -> (lat: Double, lon: Double)? {
        let key = postcode.replacingOccurrences(of: " ", with: "").uppercased()
        switch key {
        case "SW1A1AA": return (51.501364, -0.141890) // Buckingham Palace
        case "EC2M7QH": return (51.517918, -0.082611) // Liverpool Street
        case "EC2M2QS": return (51.518596, -0.083648) // EC2M 2QS approx
        case "MK91LA": return (52.041691, -0.759197) // MK9 1LA approx
        default: return nil
        }
    }
}


