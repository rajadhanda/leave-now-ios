import Foundation

enum Secrets {
    private static var dict: [String: Any] = {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let obj = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let d = obj as? [String: Any] else { return [:] }
        return d
    }()

    static var tflAppKey: String { dict[Config.tflAppKeyKey] as? String ?? "" }
    static var openWeatherKey: String { dict[Config.openWeatherKey] as? String ?? "" }
}
