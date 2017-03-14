
//  Copyright © 2017 Nahin Ahmed. All rights reserved.
//

import Foundation
import ObjectMapper

class Response: Mappable{
    required init?(map: Map) {
        
    }
    
    func mapping(map: Map) {
        
    }
}


extension Response {
    
    class Error: Response {
        var message: String?
        
        override func mapping(map: Map) {
            super.mapping(map: map)
            
            message <- map["error.message"]
        }
    }
    
    
    class Privacy: Response {
        var status : Int!
        var body : String!
        
        override func mapping(map: Map) {
            super.mapping(map: map)
            
            status <- map["status_code"]
            body <- map["body"]
        }
        
    }
}
