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

extension RegularExpression {
    func hasMatch(_ string: String) -> Bool {
        if self.firstMatch(in: string, options: [], range: NSMakeRange(0, string.lengthOfBytes(using: String.Encoding.utf8))) != nil {
            return true
        } else {
            return false
        }
    }

    func matches(_ string: String) -> [TextCheckingResult] {
        return self.matches(in: string, options: [], range: NSMakeRange(0, string.lengthOfBytes(using: String.Encoding.utf8)))
    }
}

protocol SteamGuardDelegate {
    func steamGuard(_ account: SteamGuardAccount, didFetchConfirmations confirmations: [Confirmation])
    func steamGuard(_ account: SteamGuardAccount, didRefreshSession result: Bool)
}

public class SteamGuardAccount {

    // MARK: Properties

    enum SteamGuardError: ErrorProtocol {
        case noDeviceID
        case invalidToken
    }

    var delegate: SteamGuardDelegate?

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

    /// Whether the authenticator has actually been applied to the account.
    public var fullyEnrolled: Bool = false

    public var session: SessionData = SessionData()

    private var steamGuardCodeTranslations: [UInt8] = [50, 51, 52, 53, 54, 55, 56, 57, 66, 67, 68, 70, 71, 72, 74, 75, 77, 78, 80, 81, 82, 84, 86, 87, 88, 89]

    // MARK: Functions

    func deactivateAuthenticator(_ scheme: Int = 2) -> Bool {
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

    func generateSteamGuardCodeForTime(_ time: Int) -> String {
        if sharedSecret == "" {
            return ""
        }

        let sharedSecretData = Data(base64Encoded: sharedSecret)!

        var timeArray = [UInt8](repeating: 0, count: 8)

        var time = time
        time /= 30

        for i in (1...8).reversed() {
            timeArray[i - 1] = UInt8(truncatingBitPattern: time)
            time >>= 8
        }

        var error: Unmanaged<CFError>?
        let transform = SecDigestTransformCreate(kSecDigestHMACSHA1, 0, &error)
        let inputData = timeArray.withUnsafeBufferPointer { buffer in
            Data(bytes: UnsafePointer<UInt8>(buffer.baseAddress!), count: buffer.count)
        }

        SecTransformSetAttribute(transform, kSecTransformInputAttributeName, inputData, &error)
        SecTransformSetAttribute(transform, kSecDigestHMACKeyAttribute, sharedSecretData, &error)
        let hashedData = SecTransformExecute(transform, &error) as! Data
        var hashedArray = [UInt8](repeating: 0, count: hashedData.count / sizeof(UInt8))
        (hashedData as NSData).getBytes(&hashedArray, length: hashedArray.count)

        let b = Int(hashedArray[19] & 0xF)
        var codePoint: Int = Int(hashedArray[b] & 0x7F) << 24
        codePoint |= Int(hashedArray[b + 1] & 0xFF) << 16
        codePoint |= Int(hashedArray[b + 2] & 0xFF) << 8
        codePoint |= Int(hashedArray[b + 3] & 0xFF)

        var codeArray = [UInt8](repeating: 0, count: 5)
        for i in 0..<5 {
            codeArray[i] = steamGuardCodeTranslations[codePoint % steamGuardCodeTranslations.count]
            codePoint /= steamGuardCodeTranslations.count
        }

        return String(bytes: codeArray, encoding: String.Encoding.utf8)!
    }

    func fetchConfirmations() throws -> [Confirmation] {
        let url = generateConfirmationURL()

        session.addCookies()

        let response = SteamWeb.request(url, method: "GET")

        /* Regex part */


        let confIDRegex = try! RegularExpression(pattern: "data-confid=\"(\\d+)\"", options: [])
        let confKeyRegex = try! RegularExpression(pattern: "data-key=\"(\\d+)\"", options: [])
        let confDescRegex = try! RegularExpression(pattern: "<div>((Confirm|Trade with|Sell -) .+)</div>", options: [])


        if response == nil || !(confIDRegex.hasMatch(response!) && confKeyRegex.hasMatch(response!) && confDescRegex.hasMatch(response!)) {
            if response == nil || !response!.contains("<div>Nothing to confirm</div>") {
                throw SteamGuardError.invalidToken
            }
            return []
        }

        let confIDs = confIDRegex.matches(response!)
        let confKeys = confKeyRegex.matches(response!)
        let confDescs = confDescRegex.matches(response!)
        var ret: [Confirmation] = []
        for i in 0..<confIDs.count {
            let confID = (response! as NSString).substring(with: confIDs[i].range(at: 1))
            let confKey = (response! as NSString).substring(with: confKeys[i].range(at: 1))
            let confDesc = (response! as NSString).substring(with: confDescs[i].range(at: 1))
            let conf = Confirmation(ID: confID, key: confKey, description: confDesc)
            ret.append(conf)
        }
        return ret
    }

    func fetchConfirmationsAsync() throws {
        let url = generateConfirmationURL()

        session.addCookies()

        do {
            try SteamWeb.requestAsync(url, method: "GET") { response in

                /* Regex part */


                let confIDRegex = try! RegularExpression(pattern: "data-confid=\"(\\d+)\"", options: [])
                let confKeyRegex = try! RegularExpression(pattern: "data-key=\"(\\d+)\"", options: [])
                let confDescRegex = try! RegularExpression(pattern: "<div>((Confirm|Trade with|Sell -) .+)</div>", options: [])


                if response == nil || !(confIDRegex.hasMatch(response!) && confKeyRegex.hasMatch(response!) && confDescRegex.hasMatch(response!)) {
                    if response == nil || !response!.contains("<div>Nothing to confirm</div>") {
                        throw SteamGuardError.invalidToken
                    }
                    self.delegate?.steamGuard(self, didFetchConfirmations: [])
                }

                let confIDs = confIDRegex.matches(response!)
                let confKeys = confKeyRegex.matches(response!)
                let confDescs = confDescRegex.matches(response!)
                var ret: [Confirmation] = []
                for i in 0..<confIDs.count {
                    let confID = (response! as NSString).substring(with: confIDs[i].range(at: 1))
                    let confKey = (response! as NSString).substring(with: confKeys[i].range(at: 1))
                    let confDesc = (response! as NSString).substring(with: confDescs[i].range(at: 1))
                    let conf = Confirmation(ID: confID, key: confKey, description: confDesc)
                    ret.append(conf)
                }
                self.delegate?.steamGuard(self, didFetchConfirmations: ret)
            }
        } catch let error {
            throw error
        }
    }

    func getConfirmationTradeOfferID(_ conf: Confirmation) -> Int {
        let confDetails = getConfirmationDetails(conf)
        if confDetails == nil || confDetails!["success"].boolValue == false { return -1 }

        let tradeOfferIDRegex = try! RegularExpression(pattern: "<div class=\"tradeoffer\" id=\"tradeofferid_(\\d+)\" >", options: [])
        if !tradeOfferIDRegex.hasMatch(confDetails!["html"].stringValue) { return -1 }
        return Int((confDetails!["html"].stringValue as NSString).substring(with: tradeOfferIDRegex.matches(confDetails!["html"].stringValue)[0].range(at: 1)))!
    }

    func AcceptConfirmation(_ conf: Confirmation) -> Bool {
        return sendConfirmationAjax(conf, op: "allow")
    }

    func DenyConfirmation(_ conf: Confirmation) -> Bool {
        return sendConfirmationAjax(conf, op: "cancel")
    }

    /// Refreshes the Steam session. Necessary to perform confirmations if your session has expired or changed.
    func refreshSession() -> Bool {
        let url = APIEndpoints.mobileAuthGetWGToken;
        let postData = ["access_token": session.OAuthToken]

        var response: String? = nil;
        response = SteamWeb.request(url, method: "POST", data: postData);

        if response == nil {
            return false
        }

        var refreshResponse = JSON(data: response!.data(using: .utf8)!);
        if !refreshResponse["response"].exists() || refreshResponse["response"]["token"].stringValue == "" {
            return false
        }

        let token = String(session.steamID) + "%7C%7C" + refreshResponse["response"]["token"].stringValue
        let tokenSecure = String(session.steamID) + "%7C%7C" + refreshResponse["response"]["token_secure"].stringValue;

        session.steamLogin = token;
        session.steamLoginSecure = tokenSecure;
        return true;
    }

    /// Refreshes the Steam session. Necessary to perform confirmations if your session has expired or changed.
    func refreshSessionAsync() {
        let url = APIEndpoints.mobileAuthGetWGToken;
        let postData = ["access_token": session.OAuthToken]

        SteamWeb.requestAsync(url, method: "POST", data: postData) { response in

            if response == nil {
                self.delegate?.steamGuard(self, didRefreshSession: false)
            }

            var refreshResponse = JSON(data: response!.data(using: .utf8)!)
            if !refreshResponse["response"].exists() || refreshResponse["response"]["token"].stringValue == "" {
                self.delegate?.steamGuard(self, didRefreshSession: false)
            }

            let token = String(self.session.steamID) + "%7C%7C" + refreshResponse["response"]["token"].stringValue
            let tokenSecure = String(self.session.steamID) + "%7C%7C" + refreshResponse["response"]["token_secure"].stringValue

            self.session.steamLogin = token
            self.session.steamLoginSecure = tokenSecure
            self.delegate?.steamGuard(self, didRefreshSession: true)
        }
    }

    private func getConfirmationDetails(_ conf: Confirmation) -> JSON? {
        var url = APIEndpoints.community + "/mobileconf/details/" + conf.ID + "?"
        let queryString = try! generateConfirmationQueryParams("details")
        url += queryString

        session.addCookies()
        /* let referer */ _ = generateConfirmationURL() // It's not used in C# version

        let response = SteamWeb.request(url, method: "GET")
        if response == nil || response! == "" {
            return nil
        }

        return JSON(response!)
    }

    private func sendConfirmationAjax(_ conf: Confirmation, op: String) -> Bool {
        var url = APIEndpoints.community + "/mobileconf/ajaxop";
        var queryString = "?op=" + op + "&";
        do {
            try queryString += generateConfirmationQueryParams(op);
        } catch {

        }
        queryString += "&cid=" + conf.ID + "&ck=" + conf.key;
        url += queryString;

        session.addCookies()
        /* let referer */ _ = generateConfirmationURL();

        let response = SteamWeb.request(url, method: "GET");
        if response == nil {
            return false
        }

        let confResponse = JSON(data: response!.data(using: .utf8)!)
        return confResponse["success"].boolValue;
    }

    func generateConfirmationURL(_ tag: String = "conf") -> String {
        let endpoint = APIEndpoints.community + "/mobileconf/conf?"
        let queryString = try! generateConfirmationQueryParams(tag)
        return endpoint + queryString
    }

    func generateConfirmationQueryParams(_ tag: String) throws -> String {
        if deviceID == "" {
            throw SteamGuardError.noDeviceID
        }
        let time = TimeAligner.getSteamTime()
        return "p=" + deviceID + "&a=" + String(session.steamID) + "&k=" + generateConfirmationHashForTime(time, tag: tag) + "&t=" + String(time) + "&m=android&tag=" + tag
    }

    private func generateConfirmationHashForTime(_ time: Int, tag: String) -> String {
        var time = time
        var n2 = 8
        if tag != "" {
            if tag.lengthOfBytes(using: String.Encoding.utf8) > 32 {
                n2 = 8 + 32
            } else {
                n2 = 8 + tag.lengthOfBytes(using: String.Encoding.utf8)
            }
        }
        var array = [UInt8](repeating: 0, count: n2)
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
            var tagArray = [UInt8](repeating: 0, count: tag.lengthOfBytes(using: String.Encoding.utf8))
            (tag.data(using: String.Encoding.utf8)! as NSData).getBytes(&tagArray, length: tagArray.count)
            for i in 0...n2 - 8 {
                array[8 + i] = tagArray[i]
            }
        }
        var error: Unmanaged<CFError>?
        let transform = SecDigestTransformCreate(kSecDigestHMACSHA1, 0, &error)
        let inputData = array.withUnsafeBufferPointer { buffer in
            Data(bytes: UnsafePointer<UInt8>(buffer.baseAddress!), count: buffer.count)
        }

        SecTransformSetAttribute(transform, kSecTransformInputAttributeName, inputData, &error)
        SecTransformSetAttribute(transform, kSecDigestHMACKeyAttribute, Data(base64Encoded: identitySecret)!, &error)
        let hashedData = SecTransformExecute(transform, &error) as! Data
        let encodedData = hashedData.base64EncodedString(.encodingEndLineWithLineFeed)
        let hash = encodedData.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)!

        return hash
    }

}
