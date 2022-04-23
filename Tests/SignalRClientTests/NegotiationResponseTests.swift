//
//  NegotiationResponseTests.swift
//  SignalRClientTests
//
//  Created by Pawel Kadluczka on 7/17/18.
//  Copyright © 2018 Pawel Kadluczka. All rights reserved.
//

import XCTest
@testable import SignalRClient

class NegotiationResponseTests: XCTestCase {

    public func testThatCanCreateNegotiationResponse() {
        let availableTransports = [
            TransportDescription(transportType: .webSockets, transferFormats: [.text, .binary]),
            TransportDescription(transportType: .longPolling, transferFormats: [.binary])]
        let negotiationResponse = Negotiation.Payload(connectionId: "connectionId", connectionToken: "connectionToken", version: 42, transports: availableTransports)

        XCTAssertEqual("connectionId", negotiationResponse.connectionId)
        XCTAssertEqual("connectionToken", negotiationResponse.connectionToken)
        XCTAssertEqual(42, negotiationResponse.version)
        XCTAssertTrue(availableTransports.elementsEqual(negotiationResponse.transports) { $0 === $1 })
    }

    public func testThatParseCanParseCreatesNegotiationResponseFromValidPayload() throws {
        let payload = "{\"connectionId\":\"6baUtSEmluCoKvmUIqLUJw\",\"connectionToken\": \"9AnFxsjXqnRuz4UBt2W8\",\"negotiateVersion\":1,\"availableTransports\":[{\"transport\":\"WebSockets\",\"transferFormats\":[\"Text\",\"Binary\"]},{\"transport\":\"ServerSentEvents\",\"transferFormats\":[\"Text\"]},{\"transport\":\"LongPolling\",\"transferFormats\":[\"Text\",\"Binary\"]}]}"

        let data = try XCTUnwrap(payload.data(using: .utf8))
        let negotiation = try JSONDecoder().decode(Negotiation.self, from: data)
        guard case let .payload(payload) = negotiation else {
            throw SignalRError.invalidNegotiationResponse(message: payload)
        }
        
        XCTAssertEqual("6baUtSEmluCoKvmUIqLUJw", payload.connectionId)
        XCTAssertEqual(3, payload.transports.count)
        XCTAssertEqual(.webSockets, payload.transports[0].transportType)
        XCTAssertEqual([.text, .binary], payload.transports[0].transferFormats)

        XCTAssertEqual(.serverSentEvents, payload.transports[1].transportType)
        XCTAssertEqual([.text], payload.transports[1].transferFormats)

        XCTAssertEqual(.longPolling, payload.transports[2].transportType)
        XCTAssertEqual([.text, .binary], payload.transports[2].transferFormats)
    }

    public func testThatCanCreateRedirection() {
        let redirection = Negotiation.Redirection(url: URL(string: "http://fakeuri.org")!, accessToken: "abc")

        XCTAssertEqual(URL(string: "http://fakeuri.org")!, redirection.url)
        XCTAssertEqual("abc", redirection.accessToken)
    }

    public func testThatParseParseCreatesRedirectionResponseFromValidPayload() throws {
        let payload = "{\"url\":\"http://fakeuri.org\", \"accessToken\": \"abc\"}"
        let data = try XCTUnwrap(payload.data(using: .utf8))
        let negotiation = try JSONDecoder().decode(Negotiation.self, from: data)
        guard case let .redirection(redirection) = negotiation else {
            throw SignalRError.invalidNegotiationResponse(message: payload)
        }
        
        XCTAssertEqual(URL(string: "http://fakeuri.org")!, redirection.url)
        XCTAssertEqual("abc", redirection.accessToken)
    }

    public func testThatParseThrowsForInvalidPayloads() {
        let testCases = [
            "1":
                #"typeMismatch(Swift.Dictionary<Swift.String, Any>, Swift.DecodingError.Context(codingPath: [], debugDescription: "Expected to decode Dictionary<String, Any> but found a number instead.", underlyingError: nil))"#,
            "[1]":
                #"typeMismatch(Swift.Dictionary<Swift.String, Any>, Swift.DecodingError.Context(codingPath: [], debugDescription: "Expected to decode Dictionary<String, Any> but found an array instead.", underlyingError: nil))"#,
            "{}":
                #"keyNotFound(CodingKeys(stringValue: "connectionId", intValue: nil), Swift.DecodingError.Context(codingPath: [], debugDescription: "No value associated with key CodingKeys(stringValue: \"connectionId\", intValue: nil) (\"connectionId\").", underlyingError: nil))"#,
            "{\"connectionId\": []}":
                #"typeMismatch(Swift.String, Swift.DecodingError.Context(codingPath: [CodingKeys(stringValue: "connectionId", intValue: nil)], debugDescription: "Expected to decode String but found an array instead.", underlyingError: nil))"#,
            "{\"connectionId\": \"123\", \"negotiateVersion\": 1 }":
                #"keyNotFound(CodingKeys(stringValue: "connectionToken", intValue: nil), Swift.DecodingError.Context(codingPath: [], debugDescription: "No value associated with key CodingKeys(stringValue: \"connectionToken\", intValue: nil) (\"connectionToken\").", underlyingError: nil))"#,
            "{\"connectionId\": \"123\", \"connectionToken\": 1, \"negotiateVersion\": 1}":
                #"typeMismatch(Swift.String, Swift.DecodingError.Context(codingPath: [CodingKeys(stringValue: "connectionToken", intValue: nil)], debugDescription: "Expected to decode String but found a number instead.", underlyingError: nil))"#,
            "{\"connectionId\": \"123\", \"connectionToken\": \"9AnFxsjXqnRuz4UBt2W8\", \"negotiateVersion\": \"1\" }":
                #"typeMismatch(Swift.Int, Swift.DecodingError.Context(codingPath: [CodingKeys(stringValue: "negotiateVersion", intValue: nil)], debugDescription: "Expected to decode Int but found a string/data instead.", underlyingError: nil))"#,
            "{\"connectionId\": \"123\", \"connectionToken\": \"9AnFxsjXqnRuz4UBt2W8\", \"negotiateVersion\": 1}":
                #"keyNotFound(CodingKeys(stringValue: "availableTransports", intValue: nil), Swift.DecodingError.Context(codingPath: [], debugDescription: "No value associated with key CodingKeys(stringValue: \"availableTransports\", intValue: nil) (\"availableTransports\").", underlyingError: nil))"#,
            "{\"connectionId\": \"123\", \"connectionToken\": \"9AnFxsjXqnRuz4UBt2W8\", \"negotiateVersion\": 1,\"availableTransports\": false}":
                #"typeMismatch(Swift.Array<Any>, Swift.DecodingError.Context(codingPath: [CodingKeys(stringValue: "availableTransports", intValue: nil)], debugDescription: "Expected to decode Array<Any> but found a number instead.", underlyingError: nil))"#,
            "{\"connectionId\": \"123\", \"connectionToken\": \"9AnFxsjXqnRuz4UBt2W8\", \"negotiateVersion\": 1, \"availableTransports\": [{}]}":
                #"keyNotFound(CodingKeys(stringValue: "transport", intValue: nil), Swift.DecodingError.Context(codingPath: [CodingKeys(stringValue: "availableTransports", intValue: nil), _JSONKey(stringValue: "Index 0", intValue: 0)], debugDescription: "No value associated with key CodingKeys(stringValue: \"transport\", intValue: nil) (\"transport\").", underlyingError: nil))"#,
            "{\"connectionId\": \"123\", \"connectionToken\": \"9AnFxsjXqnRuz4UBt2W8\", \"negotiateVersion\": 1,  \"availableTransports\": [{\"transport\": 42}]}":
                #"typeMismatch(Swift.String, Swift.DecodingError.Context(codingPath: [CodingKeys(stringValue: "availableTransports", intValue: nil), _JSONKey(stringValue: "Index 0", intValue: 0), CodingKeys(stringValue: "transport", intValue: nil)], debugDescription: "Expected to decode String but found a number instead.", underlyingError: nil))"#,
            "{\"connectionId\": \"123\",  \"connectionToken\": \"9AnFxsjXqnRuz4UBt2W8\", \"negotiateVersion\": 1, \"availableTransports\": [{\"transport\": \"WebSockets\"}]}":
                #"keyNotFound(CodingKeys(stringValue: "transferFormats", intValue: nil), Swift.DecodingError.Context(codingPath: [CodingKeys(stringValue: "availableTransports", intValue: nil), _JSONKey(stringValue: "Index 0", intValue: 0)], debugDescription: "No value associated with key CodingKeys(stringValue: \"transferFormats\", intValue: nil) (\"transferFormats\").", underlyingError: nil))"#,
            "{\"connectionId\": \"123\",  \"connectionToken\": \"9AnFxsjXqnRuz4UBt2W8\", \"negotiateVersion\": 1, \"availableTransports\": [{\"transport\": \"WebSockets\", \"transferFormats\":{}}]}":
                #"typeMismatch(Swift.Array<Any>, Swift.DecodingError.Context(codingPath: [CodingKeys(stringValue: "availableTransports", intValue: nil), _JSONKey(stringValue: "Index 0", intValue: 0), CodingKeys(stringValue: "transferFormats", intValue: nil)], debugDescription: "Expected to decode Array<Any> but found a dictionary instead.", underlyingError: nil))"#,
            "{\"connectionId\": \"123\",  \"connectionToken\": \"9AnFxsjXqnRuz4UBt2W8\", \"negotiateVersion\": 1, \"availableTransports\": [{\"transport\": \"WebSockets\", \"transferFormats\":[\"Text\", \"abc\"]}]}":
                #"dataCorrupted(Swift.DecodingError.Context(codingPath: [CodingKeys(stringValue: "availableTransports", intValue: nil), _JSONKey(stringValue: "Index 0", intValue: 0), CodingKeys(stringValue: "transferFormats", intValue: nil), _JSONKey(stringValue: "Index 1", intValue: 1)], debugDescription: "Cannot initialize TransferFormat from invalid String value abc", underlyingError: nil))"#,
            "{\"url\": 123}":
                #"typeMismatch(Swift.String, Swift.DecodingError.Context(codingPath: [CodingKeys(stringValue: "url", intValue: nil)], debugDescription: "Expected to decode String but found a number instead.", underlyingError: nil))"#,
            "{\"url\": \"123\"}":
                #"keyNotFound(CodingKeys(stringValue: "accessToken", intValue: nil), Swift.DecodingError.Context(codingPath: [], debugDescription: "No value associated with key CodingKeys(stringValue: \"accessToken\", intValue: nil) (\"accessToken\").", underlyingError: nil))"#,
            "{\"accessToken\": \"123\", \"url\": null}":
                #"valueNotFound(Foundation.URL, Swift.DecodingError.Context(codingPath: [CodingKeys(stringValue: "url", intValue: nil)], debugDescription: "Expected URL value but found null instead.", underlyingError: nil))"#,
            "{\"accessToken\": 123, \"url\": \"123\"}":
                #"typeMismatch(Swift.String, Swift.DecodingError.Context(codingPath: [CodingKeys(stringValue: "accessToken", intValue: nil)], debugDescription: "Expected to decode String but found a number instead.", underlyingError: nil))"#,
        ]
        
        testCases.forEach {
            let (payload, errorMessage) = $0
            do {
                let data = try XCTUnwrap(payload.data(using: .utf8))
                _ = try JSONDecoder().decode(Negotiation.self, from: data)
                XCTAssert(false, "exception expected but none thrown")
            } catch {
                XCTAssertEqual("\(error)", errorMessage)
            }
        }
    }
}
