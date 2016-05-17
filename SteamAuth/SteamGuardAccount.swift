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

public class SteamGuardAccount {

    // MARK: Properties

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

}