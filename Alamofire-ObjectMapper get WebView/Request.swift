
//  Copyright © 2017 Nahin Ahmed. All rights reserved.
//

import Foundation
import Alamofire
import ObjectMapper

let HTTPURLResponseKey = "HTTPURLResponseKey"

class Request {
    
    // MARK: - Constants
    
    #if DEBUG
    static let baseUrlString = "https://christianspaces.com/api/rest/"
    #else
    static let baseUrlString = "https://christianspaces.com/api/rest/"
    #endif
    private static let baseUrl = URL(string: baseUrlString)
    
    // Mark: - Public
    
    @discardableResult static func send<T: BaseMappable>(method: Alamofire.HTTPMethod, path: String, parameters: [String: AnyObject] = [String: AnyObject](), response done: ((_ response: T?, _ error: NSError?) -> ())? = nil) -> Request {
        
        let mapClosure = {Mapper<T>().map(JSONObject: $0)}
        return send(map: mapClosure, method: method, path: path, parameters: parameters, response: done)
    }
    
    @discardableResult static func send<T: BaseMappable>(method: Alamofire.HTTPMethod, path: String, parameters: [String: AnyObject] = [String: AnyObject](), response done: ((_ response: [T]?, _ error: NSError?) -> ())? = nil) -> Request {
        
        let mapClosure = { Mapper<T>().mapArray(JSONObject: $0)}
        return send(map: mapClosure, method: method, path: path, parameters: parameters, response: done)
    }
    
    @discardableResult static func send(method: Alamofire.HTTPMethod, path: String, parameters: [String: AnyObject] = [String: AnyObject](), response done: ((_ error:NSError?) -> ())? = nil) -> Request {
        return send(method: method, path: path, parameters: parameters){(_: Response?, error: NSError?) in
            
            if let done = done {
                done(error)
            }
            
        }
    }
    
    
    func abort(){
        dispatchGroup.notify(queue: DispatchQueue.main){
            self.dataRequest?.cancel()
        }
    }
    
    // MARK:- Private
    
    private static func send<T>(map: @escaping (Any) -> T?, method: Alamofire.HTTPMethod, path: String, parameters: [String: AnyObject] = [String: AnyObject](), response done: ((_ response: T?, _ error:NSError?) -> ())? = nil) -> Request {
        
        guard let url = URL(string: path, relativeTo: baseUrl) else {
            fatalError()
        }
        
        print("url: \(url) methods \(method) parameters: \(parameters)")
        
        var headers = HTTPHeaders()
        headers["oauth_consumer_secret"] = ""
        headers["oauth_consumer_key"] = ""
        
        
        let req = self.request(url: url, method: method, parameters: parameters, headers: headers)
        
        req.responseJSON { response in
            print("\(path) | \(response.response?.statusCode) | \(response)")
            
            var result : T? = nil
            var error : NSError? = nil
            
            switch response.result {
            case .success(let json):
                guard let code = response.response?.statusCode, (200..<300).contains(code) else {
                    
                    var errorMessage = "Error"
                    if let error = Mapper<Response.Error>().map(JSONObject: json), let message = error.message {
                        errorMessage = message
                    }
                    
                    error = networkError(message: errorMessage, response: response)
                    break
                }
                
                if let parsed = map(json) {
                    result = parsed
                }
            case .failure(let serverError):
                guard !(response.response?.statusCode != nil &&
                    (200..<300).contains(response.response!.statusCode) &&
                    response.data?.count == 0) else {
                        break
                }
                
                error = networkError(message: serverError.localizedDescription, response: response, error:  serverError as NSError)
                
                
            }
            
            if let done = done {
                done(result, error)
            }
            
        }
        
        return req
        
        
    }
    
    static func request(url: URL, method: Alamofire.HTTPMethod, parameters: [String: AnyObject], headers: HTTPHeaders) -> Request {
        
        let request = Request()
        
        if method != .get && parameters.values.contains(where: { $0 is UIImage}) {
            request.dispatchGroup.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                Alamofire.upload(
                    multipartFormData: { multipartFormData in
                        
                        // multipartFormData.append(unicornImageURL, withName: "unicorn")
                        
                        for (key, value) in parameters {
                            if let image = value as? UIImage {
                                
                                // Compress image here
                                
                                if let data = UIImageJPEGRepresentation(image, 0.7) {
                                    
                                    print("Image Data Size: \(data.count/1024) KB")
                                    
                                    multipartFormData.append(data, withName: key, fileName: "image.jpeg", mimeType: "image/jpeg")
                                }
                            } else {
                                if let data = "\(value)".data(using: String.Encoding.utf8) {
                                    multipartFormData.append(data, withName: key)
                                }
                            }
                        }
                        
                }, to: url,
                   method: method,
                   headers: headers,
                   encodingCompletion: { encodingResult in
                    switch encodingResult {
                    case .success(let upload, _, _):
                        request.dataRequest = upload
                        
                        /*
                         upload.responseJSON { response in
                         debugPrint(response)
                         }
                         */
                        
                    case .failure(let encodingError):
                        print(encodingError)
                        
                    }
                    
                }
                    
                )
                
                /*
                 
                 DispatchQueue.main.async {
                 Bounce back to the main thread to update the UI
                 }
                 
                 */
            }
            
        } else {
            
            request.dataRequest = Alamofire.request(url, method: method, parameters: parameters, encoding: (method == .get ? URLEncoding.default : JSONEncoding.default), headers: headers)
        }
        
        return request
        
    }
    
    
    static func networkError(message: String, response: Alamofire.DataResponse<Any>, error: NSError? = nil) -> NSError{
        
        var info: [String: AnyObject] = [NSLocalizedDescriptionKey: message as AnyObject, HTTPURLResponseKey: response.response ?? NSNull()]
        
        if let error = error {
            info[NSUnderlyingErrorKey] = error
        }
        
        return NSError(domain: NSStringFromClass(self), code: 0, userInfo: info)
        
    }
    
    
    
    private var dispatchGroup = DispatchGroup()
    private var dataRequest: Alamofire.DataRequest?
    
    func responseJSON (completionHandler: @escaping (Alamofire.DataResponse<Any>) -> Void){
        
        dispatchGroup.notify(queue: DispatchQueue.main) {
            self.dataRequest?.responseJSON(completionHandler: completionHandler)
        }
    }
    
    // mark:- Helpers
    
    static func imageURL(imageID: String?) -> NSURL {
        guard let imageID = imageID, imageID != "" else {
            return NSURL(fileURLWithPath: Bundle.main.path(forResource: "noImage", ofType: "png")!)
        }
        
        let ulrString = "\(baseUrlString) pictures \(imageID)"
        guard let url = NSURL(string: ulrString) else {
            fatalError()
        }
        
        return url
    }
    
}
