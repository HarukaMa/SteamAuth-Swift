//
//  Util.swift
//  SteamAuth
//
//  Created by Haruka Ma on H28/05/17.
//

import Foundation

public class Util {

    public static func newCookie(name: String, value: String, path: String, domain: String, secure: Bool = false, httpOnly: Bool = false) -> HTTPCookie {
        var properties = [
            HTTPCookiePropertyKey.name: name,
            HTTPCookiePropertyKey.value: value,
            HTTPCookiePropertyKey.path: path,
            HTTPCookiePropertyKey.domain: domain
        ]
        if secure {
            properties[HTTPCookiePropertyKey.secure] = "1"
        }
        if httpOnly {
            properties["HttpOnly" as HTTPCookiePropertyKey] = "1"
        }
        return HTTPCookie(properties: properties)!
    }

}
