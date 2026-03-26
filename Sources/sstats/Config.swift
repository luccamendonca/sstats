import Foundation

struct Config: Codable {
    var updateInterval: Double

    enum CodingKeys: String, CodingKey {
        case updateInterval = "update_interval"
    }

    static let defaultConfig = Config(updateInterval: 2.0)

    static var configDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/sstats")
    }

    static var configFile: URL {
        configDir.appendingPathComponent("config.json")
    }

    static func load() -> Config {
        let fm = FileManager.default

        if !fm.fileExists(atPath: configDir.path) {
            try? fm.createDirectory(at: configDir, withIntermediateDirectories: true)
        }

        if let data = try? Data(contentsOf: configFile),
            let config = try? JSONDecoder().decode(Config.self, from: data)
        {
            return config
        }

        let config = defaultConfig
        if let data = try? JSONEncoder().encode(config) {
            var pretty = data
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            if let prettyData = try? encoder.encode(config) {
                pretty = prettyData
            }
            try? pretty.write(to: configFile)
        }

        return config
    }
}
