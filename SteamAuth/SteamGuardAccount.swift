//
//  SteamGuardAccount.swift
//  SteamAuth
//
//  Created by Haruka Ma on H28/05/16.
//  Copyright © 平成28年 Haruka. All rights reserved.
//

import Foundation
import SwiftyJSON
import Security

extension NSRegularExpression {
    func hasMatch(string: String) -> Bool {
        if self.firstMatchInString(string, options: [], range: NSMakeRange(0, string.lengthOfBytesUsingEncoding(NSUTF8StringEncoding))) != nil {
            return true
        } else {
            return false
        }
    }

    func matches(string: String) -> [NSTextCheckingResult] {
        return self.matchesInString(string, options: [], range: NSMakeRange(0, string.lengthOfBytesUsingEncoding(NSUTF8StringEncoding)))
    }
}

public class SteamGuardAccount {

    // MARK: Properties

    enum SteamGuardError: ErrorType {
        case NoDeviceID
        case InvalidToken
    }

    public var sharedSecret: String = ""
    public var serialNumber: String = ""
    public var revocationCode: String = ""
    public var URI: String = ""
    public var serverTime: Int = 0
    public var accountName: String = ""
    public var tokenGID: String = ""
    public var identitySecret: String = ""
    public var secret1: String = ""
    public var status: Int = 0
    public var deviceID: String = ""

    /** Whether the authenticator has actually been applies to the account.
    */
    public var fullyEnrolled: Bool = false

    public var session: SessionData = SessionData()

    private var steamGuardCodeTranslations: [UInt8] = [50, 51, 52, 53, 54, 55, 56, 57, 66, 67, 68, 70, 71, 72, 74, 75, 77, 78, 80, 81, 82, 84, 86, 87, 88, 89]

    // MARK: Functions

    func deactivateAuthenticator(scheme: Int = 2) -> Bool {
        let postData: [String: String] = [
            "steamid": String(session.steamID),
            "steamguard_scheme": String(scheme),
            "revocation_code": revocationCode,
            "access_token": session.OAuthToken
        ]
        let response = SteamWeb.mobileLoginRequest(APIEndpoints.steamAPI + "/ITwoFactorService/RemoveAuthenticator/v0001", method: "POST", data: postData)
        if response == nil {
            return false
        } else {
            let removeResponse = JSON(response!)
            if removeResponse["Response"].array == nil || removeResponse["Response"]["Success"].boolValue == false {
                return false
            } else {
                return true
            }
        }
    }

    func generateSteamGuardCode() -> String {
        return generateSteamGuardCodeForTime(TimeAligner.getSteamTime())
    }

    func generateSteamGuardCodeForTime(time: Int) -> String {
        if sharedSecret == "" {
            return ""
        }

        let sharedSecretData = NSData(base64EncodedString: sharedSecret, options: .IgnoreUnknownCharacters)!

        var timeArray = [UInt8](count: 8, repeatedValue: 0)

        var time = time
        time /= 30

        for i in (1...8).reverse() {
            timeArray[i - 1] = UInt8(truncatingBitPattern: time)
            time >>= 8
        }

        var error: Unmanaged<CFError>?
        let transform = SecDigestTransformCreate(kSecDigestHMACSHA1, 0, &error)
        let inputData = timeArray.withUnsafeBufferPointer { buffer in
            NSData(bytes: buffer.baseAddress, length: buffer.count)
        }

        SecTransformSetAttribute(transform, kSecTransformInputAttributeName, inputData, &error)
        SecTransformSetAttribute(transform, kSecDigestHMACKeyAttribute, sharedSecretData, &error)
        let hashedData = SecTransformExecute(transform, &error) as! NSData
        var hashedArray = [UInt8](count: hashedData.length / sizeof(UInt8), repeatedValue: 0)
        hashedData.getBytes(&hashedArray, length: hashedArray.count)

        let b = Int(hashedArray[19] & 0xF)
        var codePoint: Int = Int(hashedArray[b] & 0x7F) << 24
        codePoint |= Int(hashedArray[b + 1] & 0xFF) << 16
        codePoint |= Int(hashedArray[b + 2] & 0xFF) << 8
        codePoint |= Int(hashedArray[b + 3] & 0xFF)

        var codeArray = [UInt8](count: 5, repeatedValue: 0)
        for i in 0..<5 {
            codeArray[i] = steamGuardCodeTranslations[codePoint % steamGuardCodeTranslations.count]
            codePoint /= steamGuardCodeTranslations.count
        }

        return String(bytes: codeArray, encoding: NSUTF8StringEncoding)!
    }

    func fetchConfirmations() throws -> [Confirmation] {
        let url = generateConfirmationURL()

        session.addCookies()

        let response = SteamWeb.request(url, method: "GET")

        /* Regex part */


        let confIDRegex = try! NSRegularExpression(pattern: "data-confid=\"(\\d+)\"", options: [])
        let confKeyRegex = try! NSRegularExpression(pattern: "data-key=\"(\\d+)\"", options: [])
        let confDescRegex = try! NSRegularExpression(pattern: "<div>((Confirm|Trade with|Sell -) .+)</div>", options: [])


        if response == nil || !(confIDRegex.hasMatch(response!) && confKeyRegex.hasMatch(response!) && confDescRegex.hasMatch(response!)) {
            if response == nil || !response!.containsString("<div>Nothing to confirm</div>") {
                throw SteamGuardError.InvalidToken
            }
            return []
        }

        let confIDs = confIDRegex.matches(response!)
        let confKeys = confKeyRegex.matches(response!)
        let confDescs = confDescRegex.matches(response!)
        var ret: [Confirmation] = []
        for i in 0..<confIDs.count {
            let confID = (response! as NSString).substringWithRange(confIDs[i].rangeAtIndex(1))
            let confKey = (response! as NSString).substringWithRange(confKeys[i].rangeAtIndex(1))
            let confDesc = (response! as NSString).substringWithRange(confDescs[i].rangeAtIndex(1))
            let conf = Confirmation(ID: confID, key: confKey, description: confDesc)
            ret.append(conf)
        }
        return ret
    }

    func generateConfirmationURL(tag: String = "conf") -> String {
        let endpoint = APIEndpoints.community + "/mobileconf/conf?"
        let queryString = try! generateConfirmationQueryParams(tag)
        return endpoint + queryString
    }

    func generateConfirmationQueryParams(tag: String) throws -> String {
        if deviceID == "" {
            throw SteamGuardError.NoDeviceID
        }
        let time = TimeAligner.getSteamTime()
        return "p=" + deviceID + "&a=" + String(session.steamID) + "&k=" + generateConfirmationHashForTime(time, tag: tag) + "&t=" + String(time) + "&m=android&tag=" + tag
    }

    private func generateConfirmationHashForTime(time: Int, tag: String) -> String {
        var time = time
        var n2 = 8
        if tag != "" {
            if tag.lengthOfBytesUsingEncoding(NSUTF8StringEncoding) > 32 {
                n2 = 8 + 32
            } else {
                n2 = 8 + tag.lengthOfBytesUsingEncoding(NSUTF8StringEncoding)
            }
        }
        var array = [UInt8](count: n2, repeatedValue: 0)
        var n3 = 8
        while true {
            let n4 = n3 - 1
            if n3 <= 0 {
                break
            }
            array[n4] = UInt8(truncatingBitPattern: time)
            time >>= 8
            n3 = n4
        }
        if tag != "" {
            var tagArray = [UInt8](count: tag.lengthOfBytesUsingEncoding(NSUTF8StringEncoding), repeatedValue: 0)
            tag.dataUsingEncoding(NSUTF8StringEncoding)!.getBytes(&tagArray, length: tagArray.count)
            for i in 0...n2 - 8 {
                array[8 + i] = tagArray[i]
            }
        }
        var error: Unmanaged<CFError>?
        let transform = SecDigestTransformCreate(kSecDigestHMACSHA1, 0, &error)
        let inputData = array.withUnsafeBufferPointer { buffer in
            NSData(bytes: buffer.baseAddress, length: buffer.count)
        }

        SecTransformSetAttribute(transform, kSecTransformInputAttributeName, inputData, &error)
        SecTransformSetAttribute(transform, kSecDigestHMACKeyAttribute, NSData(base64EncodedString: identitySecret, options: .IgnoreUnknownCharacters)!, &error)
        let hashedData = SecTransformExecute(transform, &error) as! NSData
        let encodedData = hashedData.base64EncodedStringWithOptions(.EncodingEndLineWithLineFeed)
        let hash = encodedData.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())!

        return hash
    }

}