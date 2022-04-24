//
//  Connection.swift
//  SignalRClient
//
//  Created by Pawel Kadluczka on 2/26/17.
//  Copyright © 2017 Pawel Kadluczka. All rights reserved.
//

import Foundation
import Logging

public class HttpConnection: Connection {
    private let connectionQueue: DispatchQueue
    private let startDispatchGroup: DispatchGroup

    private var url: URL
    private let options: HttpConnectionOptions
    private let transportFactory: TransportFactory
    private let logger: Logger

    private var transportDelegate: TransportDelegate?

    private var state: State
    private var transport: Transport?
    private var stopError: Error?

    public weak var delegate: ConnectionDelegate?
    public private(set) var connectionId: String?
    public var inherentKeepAlive: Bool {
        return transport!.inherentKeepAlive
    }

    private enum State: String {
        case initial = "initial"
        case connecting = "connecting"
        case connected = "connected"
        case stopped = "stopped"
    }

    public convenience init(url: URL, options: HttpConnectionOptions = HttpConnectionOptions(), logger: Logger = .signalRClient) {
        self.init(url: url, options: options, transportFactory: DefaultTransportFactory(logger: logger), logger: logger)
    }

    init(url: URL, options: HttpConnectionOptions, transportFactory: TransportFactory, logger: Logger) {
        logger.debug("HttpConnection init")
        connectionQueue = DispatchQueue(label: "SignalR.connection.queue")
        startDispatchGroup = DispatchGroup()

        self.url = url
        self.options = options
        self.transportFactory = transportFactory
        self.logger = logger
        self.state = .initial
    }

    deinit {
        logger.debug("HttpConnection deinit")
    }

    public func start() {
        logger.info("Starting connection")

        if changeState(from: .initial, to: .connecting) == nil {
            logger.error("Starting connection failed - invalid state")
            // the connection is already in use so the startDispatchGroup should not be touched to not affect it
            failOpenWithError(error: SignalRError.invalidState, changeState: false, leaveStartDispatchGroup: false)
            return
        }

        startDispatchGroup.enter()

        if options.skipNegotiation {
            transport = try! self.transportFactory.createTransport(availableTransports: [TransportDescription(transportType: TransportType.webSockets, transferFormats: [TransferFormat.text, TransferFormat.binary])])
            startTransport(connectionId: nil)
        } else {
            negotiate(negotiateUrl: createNegotiateUrl(), accessToken: nil) { payload in
                do {
                    self.transport = try self.transportFactory.createTransport(availableTransports: payload.transports)
                } catch {
                    self.logger.error("Creating transport failed: \(error)")
                    self.failOpenWithError(error: error, changeState: true)
                    return
                }

                self.startTransport(connectionId: payload.connectionToken ?? payload.connectionId)
            }
        }
    }

    private func negotiate(negotiateUrl: URL, accessToken: String?, negotiateDidComplete: @escaping (Negotiation.Payload) -> Void) {
        if let accessToken = accessToken {
            logger.debug("Overriding accessToken")
            options.accessTokenProvider = { accessToken }
        }

        let httpClient = options.httpClientFactory(options)
        httpClient.post(url: negotiateUrl, body: nil) {httpResponse, error in
            if let e = error {
                self.logger.error("Negotiate failed due to: \(e))")
                self.failOpenWithError(error: e, changeState: true)
                return
            }

            guard let httpResponse = httpResponse else {
                self.logger.error("Negotiate returned (nil) httpResponse")
                self.failOpenWithError(error: SignalRError.invalidNegotiationResponse(message: "negotiate returned nil httpResponse."), changeState: true)
                return
            }

            if httpResponse.statusCode == 200 {
                self.logger.debug("Negotiate completed with OK status code")

                do {
                    guard let payload = httpResponse.contents else {
                        throw SignalRError.invalidNegotiationResponse(message: "internal error - invalid negotiation payload")
                    }
                    
                    self.logger.debug("Negotiate response: \(String(data: payload, encoding: .utf8) ?? "(nil)")")
                    
                    let negotiation = try JSONDecoder().decode(Negotiation.self, from: payload)
                    switch negotiation {
                    case .redirection(let redirection):
                        self.logger.debug("Negotiate redirects to \(redirection.url)")
                        self.url = redirection.url
                        let negotiateUrl = redirection.url.appendingPathComponent("negotiate")
                        self.negotiate(negotiateUrl: negotiateUrl, accessToken: accessToken, negotiateDidComplete: negotiateDidComplete)
                    case .payload(let payload):
                        guard !payload.transports.isEmpty else {
                            throw SignalRError.invalidNegotiationResponse(message: "empty list of transfer formats")
                        }
                        
                        self.logger.debug("Negotiation response received")
                        negotiateDidComplete(payload)
                    }
                } catch {
                    self.logger.error("Parsing negotiate response failed: \(error)")
                    self.failOpenWithError(error: error, changeState: true)
                }
            } else {
                self.logger.error("HTTP request error. statusCode: \(httpResponse.statusCode)\ndescription:\(httpResponse.contents != nil ? String(data: httpResponse.contents!, encoding: .utf8) ?? "(nil)" : "(nil)")")
                self.failOpenWithError(error: SignalRError.webError(statusCode: httpResponse.statusCode), changeState: true)
            }
        }
    }

    private func startTransport(connectionId: String?) {
        // connection is being stopped even though start has not finished yet
        if (self.state != .connecting) {
            self.logger.info("Connection closed during negotiate")
            self.failOpenWithError(error: SignalRError.connectionIsBeingClosed, changeState: false)
            return
        }

        let startUrl = self.createStartUrl(connectionId: connectionId)
        self.transportDelegate = ConnectionTransportDelegate(connection: self, connectionId: connectionId)
        self.transport!.delegate = self.transportDelegate
        self.transport!.start(url: startUrl, options: self.options)
    }

    private func createNegotiateUrl() -> URL {
        var urlComponents = URLComponents(url: self.url, resolvingAgainstBaseURL: false)!
        var queryItems = (urlComponents.queryItems ?? []) as [URLQueryItem]
        queryItems.append(URLQueryItem(name: "negotiateVersion", value: "1"))
        urlComponents.queryItems = queryItems
        var negotiateUrl = urlComponents.url!
        negotiateUrl.appendPathComponent("negotiate")
        return negotiateUrl
    }

    private func createStartUrl(connectionId: String?) -> URL {
        if connectionId == nil {
            return self.url
        }
        var urlComponents = URLComponents(url: self.url, resolvingAgainstBaseURL: false)!
        var queryItems = (urlComponents.queryItems ?? []) as [URLQueryItem]
        queryItems.append(URLQueryItem(name: "id", value: connectionId))
        urlComponents.queryItems = queryItems
        return urlComponents.url!
    }

    private func failOpenWithError(error: Error, changeState: Bool, leaveStartDispatchGroup: Bool = true) {
        if changeState {
            _ = self.changeState(from: nil, to: .stopped)
        }

        if leaveStartDispatchGroup {
            logger.debug("Leaving startDispatchGroup (\(#function): \(#line))")
            startDispatchGroup.leave()
        }

        logger.debug("Invoking connectionDidFailToOpen")
        Util.dispatchToMainThread {
            self.delegate?.connectionDidFailToOpen(error: error)
        }
    }

    public func send(data: Data, sendDidComplete: @escaping (_ error: Error?) -> Void) {
        logger.debug("Sending data")
        guard state == .connected else {
            logger.error("Sending data failed - connection not in the 'connected' state")
            sendDidComplete(SignalRError.invalidState)
            return
        }
        transport!.send(data: data, sendDidComplete: sendDidComplete)
    }

    public func stop(stopError: Error? = nil) {
        logger.info("Stopping connection")

        let previousState = self.changeState(from: nil, to: .stopped)
        if previousState == .stopped {
            logger.info("Connection already stopped")
            return
        }

        if previousState == .initial {
            logger.warning("Connection not yet started")
            return
        }

        self.startDispatchGroup.wait()
        
        // The transport can be nil if connection was stopped immediately after starting
        // or failed to start. In this case we need to call connectionDidClose ourselves.
        if let t = transport {
            self.stopError = stopError
            t.close()
        } else {
            logger.debug("Connection being stopped before transport initialized")
            logger.debug("Invoking connectionDidClose (\(#function): \(#line))")
            Util.dispatchToMainThread {
                self.delegate?.connectionDidClose(error: stopError)
            }
        }
    }

    fileprivate func transportDidOpen(connectionId: String?) {
        logger.info("Transport started")

        let previousState = changeState(from: .connecting, to: .connected)

        logger.debug("Leaving startDispatchGroup (\(#function): \(#line))")
        startDispatchGroup.leave()
        if  previousState != nil {
            logger.debug("Invoking connectionDidOpen")
            self.connectionId = connectionId
            Util.dispatchToMainThread {
                self.delegate?.connectionDidOpen(connection: self)
            }
        } else {
            logger.debug("Connection is being stopped while the transport is starting")
        }
    }

    fileprivate func transportDidReceiveData(_ data: Data) {
        logger.debug("Received data from transport")
        Util.dispatchToMainThread {
            self.delegate?.connectionDidReceiveData(connection: self, data: data)
        }
    }

    fileprivate func transportDidClose(_ error: Error?) {
        logger.info("Transport closed")

        let previousState = changeState(from: nil, to: .stopped)
        logger.debug("Previous state \(previousState!)")

        if previousState == .connecting {
            logger.debug("Leaving startDispatchGroup (\(#function): \(#line))")
            // unblock the dispatch group if transport closed when starting (likely due to an error)
            startDispatchGroup.leave()

            logger.debug("Invoking connectionDidFailToOpen")
            Util.dispatchToMainThread {
                self.delegate?.connectionDidFailToOpen(error: self.stopError ?? error!)
            }
        } else {
            logger.debug("Invoking connectionDidClose (\(#function): \(#line))")

            self.connectionId = nil

            Util.dispatchToMainThread {
                self.delegate?.connectionDidClose(error: self.stopError ?? error)
            }
        }
    }

    private func changeState(from: State?, to: State) -> State? {
        var previousState: State? = nil

        logger.debug("Attempting to change state from: '\(from?.rawValue ?? "(nil)")' to: '\(to)'")
        connectionQueue.sync {
            if from == nil || from == state {
                previousState = state
                state = to
            }
        }
        logger.debug("Changing state to: '\(to)' \(previousState == nil ? "failed" : "succeeded")")

        return previousState
    }
}

public class ConnectionTransportDelegate: TransportDelegate {
    private weak var connection: HttpConnection?
    private let connectionId: String?

    fileprivate init(connection: HttpConnection!, connectionId: String?) {
        self.connection = connection
        self.connectionId = connectionId
    }

    public func transportDidOpen() {
        connection?.transportDidOpen(connectionId: connectionId)
    }

    public func transportDidReceiveData(_ data: Data) {
        connection?.transportDidReceiveData(data)
    }

    public func transportDidClose(_ error: Error?) {
        connection?.transportDidClose(error)
    }
}
