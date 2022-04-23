//
//  Negotiation.swift
//  SignalRClient
//
//  Created by Pawel Kadluczka on 7/8/18.
//  Copyright © 2018 Pawel Kadluczka. All rights reserved.
//
import Foundation

enum Negotiation: Decodable {
    
    struct Redirection {
        let url: URL
        let accessToken: String
    }
    
    struct Payload {
        let connectionId: String
        let connectionToken: String?
        let version: Int
        let transports: [TransportDescription]
    }
    
    case redirection(Redirection)
    case payload(Payload)
    
    enum CodingKeys: String, CodingKey {
        case url
        case accessToken
        case negotiateVersion
        case connectionId
        case connectionToken
        case availableTransports
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if container.contains(.url) {
            let url = try container.decode(URL.self, forKey: .url)
            let accessToken = try container.decode(String.self, forKey: .accessToken)
            self = .redirection(Redirection(url: url, accessToken: accessToken))
        } else {
            let connectionId = try container.decode(String.self, forKey: .connectionId)
            let version = try container.decode(Int.self, forKey: .negotiateVersion)
            var connectionToken: String? = nil
            if version > 0 {
                connectionToken = try container.decode(String.self, forKey: .connectionToken)
            }
            let transports = try container.decode([TransportDescription].self, forKey: .availableTransports)
            self = .payload(Payload(connectionId: connectionId, connectionToken: connectionToken, version: version, transports: transports))
        }
    }
}
