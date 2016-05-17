//
//  Confirmation.swift
//  SteamAuth
//
//  Created by Haruka Ma on H28/05/17.
//

import Foundation

public class Confirmation {

    public var ID: String = ""
    public var key: String = ""
    public var description: String = ""

    public enum confirmationType {
        case genericConfirmation
        case trade
        case marketSellTransaction
        case unknown
    }

    public var confType: confirmationType {
        get {
            if description == "" { return .unknown }
            if description.hasPrefix("Confirm ") { return .genericConfirmation }
            if description.hasPrefix("Trade with") { return .trade }
            if description.hasPrefix("Sell -") { return .marketSellTransaction }

            return .unknown
        }
    }

    convenience init(ID: String, key: String, description: String) {
        self.init()
        self.ID = ID
        self.key = key
        self.description = description
    }

}