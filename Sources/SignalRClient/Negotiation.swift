//
//  NegotiationResponse.swift
//  SignalRClient
//
//  Created by Pawel Kadluczka on 7/8/18.
//  Copyright © 2018 Pawel Kadluczka. All rights reserved.
//
import Foundation

/// Negotiation is used to establish a connection between a client and a server.
///
/// Documentation about the transport protocols and process are located
/// [here](https://github.com/dotnet/aspnetcore/blob/main/src/SignalR/docs/specs/TransportProtocols.md).
///
///
internal enum Negotiation {
    
    /// Negotiation Versions
    ///
    /// A negotiation request (POST) provides the query string `negotiationVersion` indicating the preferred negotiation version. Ultimately, the version is
    /// decided through this process:
    ///
    /// * If the servers minimum supported protocol version is greater than the version requested by the client it will send an error response and close the
    ///   connection.
    /// * If the server supports the request version it will respond with the requested version.
    /// * If the requested version is greater than the servers largest supported version the server will respond with its largest supported version.
    enum Version: Int, Codable {
        case v0 = 0
        case v1 = 1
    }
    
    /// A response to a negotiation request.
    ///
    /// The content type of the response is `application/json` and is a JSON payload containing properties to assist the client in establishing a persistent
    /// connection.
    ///
    /// A successful negotiate response will look similar to the following payload:
    /// ```json
    /// {
    ///   "connectionToken":"05265228-1e2c-46c5-82a1-6a5bcc3f0143",
    ///   "connectionId":"807809a5-31bf-470d-9e23-afaee35d8a0d",
    ///   "negotiateVersion":1,
    ///   "availableTransports":[
    ///     {
    ///       "transport": "WebSockets",
    ///       "transferFormats": [ "Text", "Binary" ]
    ///     },
    ///     {
    ///       "transport": "ServerSentEvents",
    ///       "transferFormats": [ "Text" ]
    ///     },
    ///     {
    ///       "transport": "LongPolling",
    ///       "transferFormats": [ "Text", "Binary" ]
    ///     }
    ///   ]
    /// }
    /// ```
    enum Response: Decodable {
        /// A response which should stop the connection attempt.
        ///
        /// - parameters:
        ///   - error: Gives details about why the negotiate failed.
        case error(String)
        /// `Negotiation.Response` Redirection
        ///
        /// A redirect response which tells the client which URL and optionally access token to use as a result.
        ///
        /// - parameters:
        ///   - url: The URL to which the client should connect.
        ///   - accessToken: Optional bearer token for accessing the specified url.
        case redirection(url: URL, accessToken: String?)
        /// `Negotiation.Response` Version 0
        ///
        /// When the server and client agree on version 0 the server response will include a "connectionId" property that is used in the "id" query string for
        /// the HTTP requests.
        ///
        /// - parameters:
        ///   - connectionId: ID used in order to correlate sends and receives in transports. (Required in Long Polling and Server-Sent Events).
        ///   - availableTransports: List which describes the transports (`TransportDescription`) the server supports.
        case version0(connectionId: String, availableTransports: [TransportDescription])
        /// `Negotiation.Response` Version 1
        ///
        /// When the server and client agree on version 1 the server response will include a `connectionToken` property in addition to the `connectionId`
        /// property. The value of the `connectionToken` property will be used in the "id" query string for the HTTP requests.
        ///
        /// - parameters:
        ///   - connectionId: The ID by which other clients can refer to this connection.
        ///   - connectionToken: ID used in order to correlate sends and receives in transports. (Required in Long Polling and Server-Sent Events).
        ///   - availableTransports: List which describes the transports (`TransportDescription`) the server supports.
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
                let accessToken = try container.decodeIfPresent(String.self, forKey: .accessToken)
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
