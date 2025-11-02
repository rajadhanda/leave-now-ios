import Foundation

/// Maps UK rail station names to CRS (Computer Reservation System) codes
/// Handles fuzzy matching for variations in station names (e.g., "London Euston" vs "Euston")
struct StationNameMapper {
    /// Dictionary mapping common station name variations to CRS codes
    private static let stationMap: [String: String] = [
        // Major London termini
        "euston": "EUS",
        "london euston": "EUS",
        "milton keynes central": "MKC",
        "milton keynes": "MKC",
        "mkc": "MKC",
        "liverpool street": "LST",
        "liverpool st": "LST",
        "lst": "LST",
        "kings cross": "KGX",
        "king's cross": "KGX",
        "king's cross st pancras": "KGX",
        "kgx": "KGX",
        "paddington": "PAD",
        "padd": "PAD",
        "waterloo": "WAT",
        "victoria": "VIC",
        "charing cross": "CHX",
        "cannon street": "CST",
        "london bridge": "LBG",
        "fenchurch street": "FST",
        "moorgate": "MOG",
        "blackfriars": "BFR",
        "marylebone": "MYB",
        
        // Other major stations
        "birmingham new street": "BHM",
        "birmingham new st": "BHM",
        "manchester piccadilly": "MAN",
        "manchester picc": "MAN",
        "leeds": "LDS",
        "glasgow central": "GLC",
        "edinburgh waverley": "EDB",
        "bristol temple meads": "BRI",
        "reading": "RDG",
        "oxford": "OXF",
        "cambridge": "CBG",
        "brighton": "BTN",
        "gatwick airport": "GTW",
        "heathrow airport": "HXX",
        "stansted airport": "SSD",
        "luton airport": "LTN",
    ]
    
    /// Maps a station name to its CRS code
    /// - Parameter stationName: Station name (case-insensitive, handles variations)
    /// - Returns: CRS code if found, nil otherwise
    static func crsCode(for stationName: String) -> String? {
        guard !stationName.isEmpty else { return nil }
        
        // Normalize: lowercase, trim whitespace
        let normalized = stationName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Direct lookup
        if let crs = stationMap[normalized] {
            return crs
        }
        
        // Fuzzy matching: check if any key contains the normalized name or vice versa
        for (key, crs) in stationMap {
            if normalized.contains(key) || key.contains(normalized) {
                return crs
            }
        }
        
        // Check for common suffixes/prefixes
        let withoutLondon = normalized.replacingOccurrences(of: "london ", with: "")
        if withoutLondon != normalized, let crs = stationMap[withoutLondon] {
            return crs
        }
        
        return nil
    }
}

