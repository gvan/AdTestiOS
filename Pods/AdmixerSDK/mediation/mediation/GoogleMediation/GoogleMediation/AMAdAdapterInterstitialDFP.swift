//
//  AMAdAdapterInterstitialDFP.swift
//  GoogleMediation
//
//  Created by Admixer on 29.01.2021.
//

import AdmixerSDK
import GoogleMobileAds

public class AMAdAdapterInterstitialDFP: NSObject, AMCustomAdapterInterstitial, GADFullScreenContentDelegate {
    
    required override public init() {
        
    }
    
    public var interstitialDelegate: (AMCustomAdapterInterstitialDelegate)?
    
    public var delegate: AMCustomAdapterDelegate? {
        get {interstitialDelegate}
        set {interstitialDelegate = newValue as? AMCustomAdapterInterstitialDelegate}
    }
    
    private var interstitialAd: GAMInterstitialAd?
    
    public func requestAd(withParameter parameterString: String?, adUnitId idString: String?, targetingParameters: AMTargetingParameters?) {
        
        GAMInterstitialAd.load(withAdManagerAdUnitID: idString!,
                               request: createRequest(from: targetingParameters),
                               completionHandler: { (ad, error) in
                                if let error = error {
                                    AMLogDebug("GAM interstitial failed to load with error \(error.localizedDescription)")
                                    let code: AMAdResponseCode? = AMAdAdapterBase.parseErrorCode(from: error as NSError)
                                    self.delegate?.didFail(toLoadAd: code ?? .amAdResponseInternalError)
                                    return
                                }
                                AMLogDebug("GAM interstitial did load")
                                self.interstitialAd = ad
                                self.interstitialAd?.fullScreenContentDelegate = self
                                self.interstitialDelegate?.didLoadInterstitialAd(self)
                            })
    }
    
    func createRequest(from targetingParameters: AMTargetingParameters?) -> GAMRequest? {
        return AMAdAdapterBase.gamRequest(from: targetingParameters)
    }
    
    public func present(from viewController: UIViewController?) {
        if let ad = interstitialAd {
            ad.present(fromRootViewController: viewController!)
        } else {
            AMLogDebug("Failed to present ad")
        }
    }
    
    public func isReady() -> Bool {
        return interstitialAd != nil
    }
    
    public func adDidPresentFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        delegate?.didPresentAd()
    }
    
    public func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        delegate?.didCloseAd()
    }
    
    public func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        AMLogDebug("GAM interstitial failed to present with error: \(error.localizedDescription)")
        let code: AMAdResponseCode? = AMAdAdapterBase.parseErrorCode(from: error as NSError)
        self.delegate?.didFail(toLoadAd: code ?? .amAdResponseInternalError)
    }
    
    deinit {
        AMLogDebug("GAM interstitial being destroyed")
        interstitialAd?.fullScreenContentDelegate = nil
        interstitialAd = nil
    }
    
}
