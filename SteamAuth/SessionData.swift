//
//  SessionData.swift
//  SteamAuth
//
//  Created by Haruka Ma on H28/05/17.
//

import Foundation

public class SessionData {

    // MARK - Properties

    public var sessionID: String = ""
    public var steamLogin: String = ""
    public var steamLoginSecure: String = ""
    public var webCookie: String = ""
    public var OAuthToken: String = ""
    public var steamID: UInt64 = 0

    // MARK - Functions

    public func addCookies() {
        let cookieStorage = HTTPCookieStorage.shared()
        cookieStorage.cookieAcceptPolicy = .always

        cookieStorage.setCookie(Util.newCookie(
            name: "mobileClientVersion",
            value: "0 (2.1.3)",
            path: "/",
            domain: ".steamcommunity.com"
            ))
        cookieStorage.setCookie(Util.newCookie(
            name: "mobileClient",
            value: "android",
            path: "/",
            domain: ".steamcommunity.com"
            ))

        cookieStorage.setCookie(Util.newCookie(
            name: "steamid",
            value: String(steamID),
            path: "/",
            domain: ".steamcommunity.com"
            ))
        cookieStorage.setCookie(Util.newCookie(
            name: "steamLogin",
            value: steamLogin,
            path: "/",
            domain: ".steamcommunity.com",
            httpOnly: true
            ))

        cookieStorage.setCookie(Util.newCookie(
            name: "steamLoginSecure",
            value: steamLoginSecure,
            path: "/",
            domain: ".steamcommunity.com",
            httpOnly: true,
            secure: true
            ))
        cookieStorage.setCookie(Util.newCookie(
            name: "Steam_Language",
            value: "english",
            path: "/",
            domain: ".steamcommunity.com"
            ))
        cookieStorage.setCookie(Util.newCookie(
            name: "dob",
            value: "",
            path: "/",
            domain: ".steamcommunity.com"
            ))
        cookieStorage.setCookie(Util.newCookie(
            name: "sessionid",
            value: sessionID,
            path: "/",
            domain: ".steamcommunity.com"
            ))

    }

}
