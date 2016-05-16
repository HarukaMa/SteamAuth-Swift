//
//  Util.swift
//  SteamAuth
//
//  Created by Haruka Ma on H28/05/17.
//

import Foundation

public class Util {

    public static func newCookie(name name: String, value: String, path: String, domain: String, secure: Bool = false, httpOnly: Bool = false) -> NSHTTPCookie {
        var properties = [
            NSHTTPCookieName: name,
            NSHTTPCookieValue: value,
            NSHTTPCookiePath: path,
            NSHTTPCookieDomain: domain
        ]
        if secure {
            properties[NSHTTPCookieSecure] = "1"
        }
        if httpOnly {
            properties["HttpOnly"] = "1"
        }
        return NSHTTPCookie(properties: properties)!
    }

}