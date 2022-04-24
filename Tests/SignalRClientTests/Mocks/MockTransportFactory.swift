import Foundation
@testable import SignalRClient

typealias TestTransportFactory = MockTransportFactory

class MockTransportFactory: TransportFactory {
    public var currentTransport: Transport?

    func createTransport(availableTransports: [TransportDescription]) throws -> Transport {
        if availableTransports.contains(where: {$0.transportType == .webSockets}) {
            currentTransport = WebsocketsTransport(logger: .signalRClient)
        } else if availableTransports.contains(where: {$0.transportType == .longPolling}) {
            currentTransport = LongPollingTransport(logger: .signalRClient)
        }
        return currentTransport!
    }
}
