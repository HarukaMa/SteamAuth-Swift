//
//  SteamWeb.swift
//  SteamAuth
//
//  Created by Haruka Ma on H28/05/16.
//

import Foundation

public class SteamWeb {
    /**
     Perform a mobile login request.
     - parameter url: API URL.
     - parameter method: GET or POST.
     - parameter data: Name-data pairs.
     - Note: We try to use the same NSHTTPCookieStorage as we can only have a singleton of it. It seems we don't need separate CookieStorage anyway.
    */
    public static func mobileLoginRequest(url: String, method: String, data: [String: String] = [:], headers: [String: String] = [:]) -> String? {
        return request(url,
                method: method,
                data: data,
                headers: headers,
                referer: APIEndpoints.community + "/mobilelogin?oauth_client_id=DE45CD61&oauth_scope=read_profile%20write_profile%20read_client%20write_client"
        )
    }

    public static func request(url: String, method: String, data: [String: String] = [:], headers: [String: String] = [:], referer: String = APIEndpoints.community) -> String? {
        var url = url
        let query = data.map { k, v in
            k.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())! + "=" + v.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())!
            }.joinWithSeparator("&")

        if method == "GET" {
            url += (url.containsString("?") ? "&" : "?") + query
        }

        let request = NSMutableURLRequest(URL: NSURL(string: url)!)
        request.HTTPMethod = method
        request.setValue("text/javascript, text/html, application/xml, text/xml, */*", forHTTPHeaderField: "Accept")
        request.setValue("Mozilla/5.0 (Linux; U; Android 4.1.1; en-us; Google Nexus 4 - 4.1.1 - API 16 - 768x1280 Build/JRO03S) AppleWebKit/534.30 (KHTML, like Gecko) Version/4.0 Mobile Safari/534.30", forHTTPHeaderField: "User-Agent")
        request.setValue(referer, forHTTPHeaderField: "Referer")

        request.allHTTPHeaderFields = headers

        let cookieStorage = NSHTTPCookieStorage.sharedHTTPCookieStorage()
        cookieStorage.cookieAcceptPolicy = .Always
        let cookieHeaders = NSHTTPCookie.requestHeaderFieldsWithCookies(cookieStorage.cookies!)
        request.allHTTPHeaderFields = cookieHeaders

        if method == "POST" {
            request.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
            request.setValue(String(query.lengthOfBytesUsingEncoding(NSUTF8StringEncoding)), forHTTPHeaderField: "Content-Length")
        }

        var result: String?
        // We use semaphore to make the request sync.
        let semaphore = dispatch_semaphore_create(0)

        let task = NSURLSession.sharedSession().dataTaskWithRequest(request) { (data, response, error) in
            if error == nil {
                result = String(data: data!, encoding: NSUTF8StringEncoding)
                let cookies = NSHTTPCookie.cookiesWithResponseHeaderFields((response as! NSHTTPURLResponse).allHeaderFields as! [String: String], forURL: response!.URL!)
                cookieStorage.setCookies(cookies, forURL: response!.URL!, mainDocumentURL: nil)
            } else {
                result = nil
            }
            dispatch_semaphore_signal(semaphore)
        }
        task.resume()

        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)

        return result

    }

    public static func requestAsync(url: String, method: String, data: [String: String] = [:], headers: [String: String] = [:], referer: String = APIEndpoints.community, completionHandler: (response: String?) -> Void) {
        var url = url
        let query = data.map { k, v in
            k.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())! + "=" + v.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())!
            }.joinWithSeparator("&")

        if method == "GET" {
            url += (url.containsString("?") ? "&" : "?") + query
        }

        let request = NSMutableURLRequest(URL: NSURL(string: url)!)
        request.HTTPMethod = method
        request.setValue("text/javascript, text/html, application/xml, text/xml, */*", forHTTPHeaderField: "Accept")
        request.setValue("Mozilla/5.0 (Linux; U; Android 4.1.1; en-us; Google Nexus 4 - 4.1.1 - API 16 - 768x1280 Build/JRO03S) AppleWebKit/534.30 (KHTML, like Gecko) Version/4.0 Mobile Safari/534.30", forHTTPHeaderField: "User-Agent")
        request.setValue(referer, forHTTPHeaderField: "Referer")

        request.allHTTPHeaderFields = headers

        let cookieStorage = NSHTTPCookieStorage.sharedHTTPCookieStorage()
        cookieStorage.cookieAcceptPolicy = .Always
        let cookieHeaders = NSHTTPCookie.requestHeaderFieldsWithCookies(cookieStorage.cookies!)
        request.allHTTPHeaderFields = cookieHeaders

        if method == "POST" {
            request.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
            request.setValue(String(query.lengthOfBytesUsingEncoding(NSUTF8StringEncoding)), forHTTPHeaderField: "Content-Length")
        }

        let task = NSURLSession.sharedSession().dataTaskWithRequest(request) { (data, response, error) in
            if error == nil {
                completionHandler(response: String(data: data!, encoding: NSUTF8StringEncoding))
                let cookies = NSHTTPCookie.cookiesWithResponseHeaderFields((response as! NSHTTPURLResponse).allHeaderFields as! [String: String], forURL: response!.URL!)
                cookieStorage.setCookies(cookies, forURL: response!.URL!, mainDocumentURL: nil)
            } else {
                completionHandler(response: nil)
            }
        }
        task.resume()
        
    }
}