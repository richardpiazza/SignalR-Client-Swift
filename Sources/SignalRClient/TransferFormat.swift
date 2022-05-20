//
//  TransferFormat.swift
//  SignalRClient
//
//  Created by Pawel Kadluczka on 7/22/18.
//  Copyright © 2018 Pawel Kadluczka. All rights reserved.
//

import Foundation

public enum TransferFormat: String, Decodable {
    case text = "Text"
    case binary = "Binary"
}
