//
//  TimeAligner.swift
//  SteamAuth
//
//  Created by Haruka Ma on H28/05/17.
//

import Foundation
import SwiftyJSON

/** Class to help align system time with the Steam server time. Not super advanced; probably not taking some things into account that it should.
    Necessary to generate up-to-date codes. In general, this will have an error of less than a second, assuming Steam is operational.
 */
public struct TimeAligner {

    private static var aligned = false
    private static var timeDifference = 0

    public static func getSteamTime() -> Int {
        if !aligned {
            alignTime()
        }
        return Int(Date().timeIntervalSince1970) + timeDifference
    }

    public static func getSteamTimeAsync(_ completionHandler: (steamTime: Int) -> Void) {
        if !aligned {
            alignTimeAsync() { _ in
                completionHandler(steamTime: Int(Date().timeIntervalSince1970) + timeDifference)
            }
        }
    }

    public static func alignTime() {
        let currentTime = Int(Date().timeIntervalSince1970)

        let request = NSMutableURLRequest(url: URL(string: APIEndpoints.twoFactorTimeQuery)!)
        request.httpMethod = "POST"
        request.httpBody = "steamid=0".data(using: String.Encoding.utf8)

        let semaphore = DispatchSemaphore(value: 0)
        let task = URLSession.shared().dataTask(with: request as URLRequest) { data, response, error in
            if error == nil {
                let query = JSON(data: data!)
                timeDifference = query["response"]["server_time"].intValue - currentTime
                aligned = true
            }
            semaphore.signal()
        }
        task.resume()
        _ = semaphore.wait(timeout: DispatchTime.distantFuture)
    }

    public static func alignTimeAsync(_ completionHandler: (Void) -> Void) {
        let currentTime = Int(Date().timeIntervalSince1970)

        let request = NSMutableURLRequest(url: URL(string: APIEndpoints.twoFactorTimeQuery)!)
        request.httpMethod = "POST"
        request.httpBody = "steamid=0".data(using: String.Encoding.utf8)

        let task = URLSession.shared().dataTask(with: request as URLRequest) { data, response, error in
            if error == nil {
                let query = JSON(data: data!)
                timeDifference = query["response"]["server_time"].intValue - currentTime
                aligned = true
            }
            completionHandler()
        }
        task.resume()
    }

}
