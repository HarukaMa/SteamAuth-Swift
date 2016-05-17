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
        return Int(NSDate().timeIntervalSince1970) + timeDifference
    }

    public static func getSteamTimeAsync(completionHandler: (steamTime: Int) -> Void) {
        if !aligned {
            alignTimeAsync() { _ in
                completionHandler(steamTime: Int(NSDate().timeIntervalSince1970) + timeDifference)
            }
        }
    }

    public static func alignTime() {
        let currentTime = Int(NSDate().timeIntervalSince1970)

        let request = NSMutableURLRequest(URL: NSURL(string: APIEndpoints.twoFactorTimeQuery)!)
        request.HTTPMethod = "POST"
        request.HTTPBody = "steamid=0".dataUsingEncoding(NSUTF8StringEncoding)

        let semaphore = dispatch_semaphore_create(0)
        let task = NSURLSession.sharedSession().dataTaskWithRequest(request) { data, response, error in
            if error == nil {
                let query = JSON(data: data!)
                timeDifference = query["response"]["server_time"].intValue - currentTime
                aligned = true
            }
            dispatch_semaphore_signal(semaphore)
        }
        task.resume()
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
    }

    public static func alignTimeAsync(completionHandler: Void -> Void) {
        let currentTime = Int(NSDate().timeIntervalSince1970)

        let request = NSMutableURLRequest(URL: NSURL(string: APIEndpoints.twoFactorTimeQuery)!)
        request.HTTPMethod = "POST"
        request.HTTPBody = "steamid=0".dataUsingEncoding(NSUTF8StringEncoding)

        let task = NSURLSession.sharedSession().dataTaskWithRequest(request) { data, response, error in
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