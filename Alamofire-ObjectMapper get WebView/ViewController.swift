
//  Copyright © 2017 Nahin Ahmed. All rights reserved.
//

import UIKit
import Alamofire

class ViewController: UIViewController {
    
    @IBOutlet weak var webView: UIWebView!
    override func viewDidLoad() {
        super.viewDidLoad()
        
        Request.send(method: .get, path: "help/privacy"){(privacy: Response.Privacy?, error) in
            
            guard let status = privacy?.status, status == 200 else {
                return
            }
            
            if let privacyBody = privacy?.body {
                self.webView.loadHTMLString(privacyBody, baseURL: nil)
            }
            
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
}

