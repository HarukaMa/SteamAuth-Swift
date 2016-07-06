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
    public static func mobileLoginRequest(_ url: String, method: String, data: [String: String] = [:], headers: [String: String] = [:]) -> String? {
        return request(url,
                method: method,
                data: data,
                headers: headers,
                referer: APIEndpoints.community + "/mobilelogin?oauth_client_id=DE45CD61&oauth_scope=read_profile%20write_profile%20read_client%20write_client"
        )
    }

    public static func request(_ url: String, method: String, data: [String: String] = [:], headers: [String: String] = [:], referer: String = APIEndpoints.community) -> String? {
        var url = url
        let query = data.map { k, v in
            k.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)! + "=" + v.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)!
            }.joined(separator: "&")

        if method == "GET" {
            url += (url.contains("?") ? "&" : "?") + query
        }

        let request = NSMutableURLRequest(url: URL(string: url)!)
        request.httpMethod = method
        request.setValue("text/javascript, text/html, application/xml, text/xml, */*", forHTTPHeaderField: "Accept")
        request.setValue("Mozilla/5.0 (Linux; U; Android 4.1.1; en-us; Google Nexus 4 - 4.1.1 - API 16 - 768x1280 Build/JRO03S) AppleWebKit/534.30 (KHTML, like Gecko) Version/4.0 Mobile Safari/534.30", forHTTPHeaderField: "User-Agent")
        request.setValue(referer, forHTTPHeaderField: "Referer")

        request.allHTTPHeaderFields = headers

        let cookieStorage = HTTPCookieStorage.shared()
        cookieStorage.cookieAcceptPolicy = .always
        let cookieHeaders = HTTPCookie.requestHeaderFields(with: cookieStorage.cookies!)
        request.allHTTPHeaderFields = cookieHeaders

        if method == "POST" {
            request.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
            request.setValue(String(query.lengthOfBytes(using: String.Encoding.utf8)), forHTTPHeaderField: "Content-Length")
        }

        var result: String?
        // We use semaphore to make sync request.
        let semaphore = DispatchSemaphore(value: 0)

        let task = URLSession.shared().dataTask(with: request as URLRequest) { (data, response, error) in
            if error == nil {
                result = String(data: data!, encoding: String.Encoding.utf8)
                let cookies = HTTPCookie.cookies(withResponseHeaderFields: (response as! HTTPURLResponse).allHeaderFields as! [String: String], for: response!.url!)
                cookieStorage.setCookies(cookies, for: response!.url!, mainDocumentURL: nil)
            } else {
                result = nil
            }
            semaphore.signal()
        }
        task.resume()

        _ = semaphore.wait(timeout: DispatchTime.distantFuture)

        return result

    }

    public static func requestAsync(_ url: String, method: String, data: [String: String] = [:], headers: [String: String] = [:], referer: String = APIEndpoints.community, completionHandler: (response: String?) throws -> Void) rethrows {
        var url = url
        let query = data.map { k, v in
            k.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)! + "=" + v.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)!
            }.joined(separator: "&")

        if method == "GET" {
            url += (url.contains("?") ? "&" : "?") + query
        }

        let request = NSMutableURLRequest(url: URL(string: url)!)
        request.httpMethod = method
        request.setValue("text/javascript, text/html, application/xml, text/xml, */*", forHTTPHeaderField: "Accept")
        request.setValue("Mozilla/5.0 (Linux; U; Android 4.1.1; en-us; Google Nexus 4 - 4.1.1 - API 16 - 768x1280 Build/JRO03S) AppleWebKit/534.30 (KHTML, like Gecko) Version/4.0 Mobile Safari/534.30", forHTTPHeaderField: "User-Agent")
        request.setValue(referer, forHTTPHeaderField: "Referer")

        request.allHTTPHeaderFields = headers

        let cookieStorage = HTTPCookieStorage.shared()
        cookieStorage.cookieAcceptPolicy = .always
        let cookieHeaders = HTTPCookie.requestHeaderFields(with: cookieStorage.cookies!)
        request.allHTTPHeaderFields = cookieHeaders

        if method == "POST" {
            request.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
            request.setValue(String(query.lengthOfBytes(using: String.Encoding.utf8)), forHTTPHeaderField: "Content-Length")
        }

        let task = URLSession.shared().dataTask(with: request as URLRequest) { (data, response, error) in
            if error == nil {
                try! completionHandler(response: String(data: data!, encoding: String.Encoding.utf8))
                let cookies = HTTPCookie.cookies(withResponseHeaderFields: (response as! HTTPURLResponse).allHeaderFields as! [String: String], for: response!.url!)
                cookieStorage.setCookies(cookies, for: response!.url!, mainDocumentURL: nil)
            } else {
                try! completionHandler(response: nil)
            }
        }
        task.resume()
        
    }
}
