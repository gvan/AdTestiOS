//
//  AMAdAdapterBase.swift
//  GoogleMediation
//
//  Created by Admixer on 29.01.2021.
//

import AdmixerSDK
import GoogleMobileAds

class AMAdAdapterBase: NSObject {
    
    class func googleAdRequest(from targetingParameters: AMTargetingParameters?) -> GADRequest? {
        self.fillRequestWithParameters(GADRequest(), from: targetingParameters)
    }
    
    class func gamRequest(from targetingParameters: AMTargetingParameters?) -> GAMRequest? {
        (self.fillRequestWithParameters(GAMRequest(), from: targetingParameters) as! GAMRequest)
    }
    
    class func fillRequestWithParameters(_ gadRequest: GADRequest?, from targetingParameters: AMTargetingParameters?) -> GADRequest? {
        if let contentURL = targetingParameters?.customKeywords?["content_url"], !contentURL.isEmpty {
            gadRequest?.contentURL = contentURL;
            
            var dictWithoutContentUrl = targetingParameters?.customKeywords
            dictWithoutContentUrl?.removeValue(forKey: "content_url")
            targetingParameters?.customKeywords = dictWithoutContentUrl
        }
        
        if let location = targetingParameters?.location {
            gadRequest?.setLocationWithLatitude(location.latitude, longitude: location.longitude, accuracy: location.horizontalAccuracy)
        }
        
        let extras = GADExtras()
        var extrasDictionary = targetingParameters?.customKeywords
        if extrasDictionary == nil {
            extrasDictionary = [:]
        }
        
        if let age = targetingParameters?.age {
            extrasDictionary?["Age"] = age
        }
        
        extras.additionalParameters = extrasDictionary
        gadRequest?.register(extras)
        
        return gadRequest
    }
    
    public class func parseErrorCode(from error: NSError?) -> AMAdResponseCode? {
        var code = AMAdResponseCode.amAdResponseInternalError
        guard let err = error else { return code }
        
        let gadErrorCode = GADErrorCode(rawValue: err.code)
        switch gadErrorCode {
        case .invalidRequest:
            code = .amAdResponseInvalidRequest
        case .noFill:
            code = .amAdResponseUnableToFill
        case .networkError:
            code = .amAdResponseNetworkError
        case .serverError:
            code = .amAdResponseNetworkError
        case .osVersionTooLow:
            code = .amAdResponseInternalError
        case .timeout:
            code = .amAdResponseNetworkError
        case .mediationDataError:
            code = .amAdResponseInvalidRequest
        case .mediationInvalidAdSize:
            code = .amAdResponseInvalidRequest
        case .internalError:
            code = .amAdResponseInternalError
        case .invalidArgument:
            code = .amAdResponseInvalidRequest
        default:
            code = .amAdResponseInternalError
        }
        return code
    }
    
}
