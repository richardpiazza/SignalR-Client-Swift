import Foundation

internal class TransportDescription: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case transportType = "transport"
        case transferFormats
    }
    
    let transportType: TransportType
    let transferFormats: [TransferFormat]

    init(transportType: TransportType, transferFormats: [TransferFormat]) {
        self.transportType = transportType
        self.transferFormats = transferFormats
    }
}
