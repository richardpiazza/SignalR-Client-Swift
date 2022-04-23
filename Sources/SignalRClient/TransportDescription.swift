import Foundation

/// A description of a specific `Transport` type and available `TransferFormat`s.
class TransportDescription: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case transport
        case transferFormats
    }
    
    let transportType: TransportType
    let transferFormats: [TransferFormat]
    
    init(
        transportType: TransportType,
        transferFormats: [TransferFormat]
    ) {
        self.transportType = transportType
        self.transferFormats = transferFormats
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeRawValue = try container.decode(String.self, forKey: .transport)
        transportType = try TransportType.fromString(transportName: typeRawValue)
        transferFormats = try container.decode([TransferFormat].self, forKey: .transferFormats)
    }
}
