import Foundation

struct ParkLocation: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var latitude: Double?
    var longitude: Double?
    var name: String?
    var areaName: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case latitude
        case longitude
        case name
        case areaName
    }

    init(
        id: UUID = UUID(),
        latitude: Double? = nil,
        longitude: Double? = nil,
        name: String? = nil,
        areaName: String? = nil
    ) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.name = name
        self.areaName = areaName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
        self.longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        self.areaName = try container.decodeIfPresent(String.self, forKey: .areaName)
    }
}
