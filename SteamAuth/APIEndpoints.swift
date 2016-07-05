//
//  APIEndpoints.swift
//  SteamAuth
//
//  Created by Haruka Ma on H28/05/16.
//

import Foundation

public struct APIEndpoints {

    static let steamAPI = "https://api.steampowered.com"
    static let community = "https://steamcommunity.com"
    static let mobileAuth = steamAPI + "/IMobileAuthService/%s/v0001"
    static let mobileAuthGetWGToken = mobileAuth.replacingOccurrences(of: "%s", with: "GetWGToken")
    static let twoFactor = steamAPI + "/ITwoFactorService/%s/v0001"
    static let twoFactorTimeQuery = twoFactor.replacingOccurrences(of: "%s", with: "QueryTime")

}
