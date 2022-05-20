//
//  NegotiationResponse.swift
//  SignalRClient
//
//  Created by Pawel Kadluczka on 7/8/18.
//  Copyright © 2018 Pawel Kadluczka. All rights reserved.
//
import Foundation

internal enum Negotiation {
    
    enum Version: Int, Codable {
        case v0 = 0
        case v1 = 1
    }
    
    enum Response: Decodable {
        case error(String)
        case redirection(url: URL, accessToken: String)
        case version0(connectionId: String, availableTransports: [TransportDescription])
        case version1(connectionId: String, connectionToken: String, availableTransports: [TransportDescription])
        
        enum CodingKeys: String, CodingKey {
            case accessToken
            case availableTransports
            case connectionId
            case connectionToken
            case error
            case negotiateVersion
            case url
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            if container.contains(.error) {
                let error = try container.decode(String.self, forKey: .error)
                self = .error(error)
            } else if container.contains(.url) {
                let url = try container.decode(URL.self, forKey: .url)
                let accessToken = try container.decode(String.self, forKey: .accessToken)
                self = .redirection(url: url, accessToken: accessToken)
            } else {
                let version = try container.decode(Version.self, forKey: .negotiateVersion)
                let connectionId = try container.decode(String.self, forKey: .connectionId)
                let transports = try container.decode([TransportDescription].self, forKey: .availableTransports)
                switch version {
                case .v1:
                    let connectionToken = try container.decode(String.self, forKey: .connectionToken)
                    self = .version1(connectionId: connectionId, connectionToken: connectionToken, availableTransports: transports)
                default:
                    self = .version0(connectionId: connectionId, availableTransports: transports)
                }
            }
        }
    }
    
}
