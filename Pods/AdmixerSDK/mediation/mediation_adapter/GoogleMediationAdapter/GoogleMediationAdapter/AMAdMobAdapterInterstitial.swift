//
//  AMAdMobAdapterInterstitial.swift
//  GoogleMediationAdapter
//
//  Created by Admixer on 02.02.2021.
//

import AdmixerSDK
import GoogleMobileAds

public class AMAdMobAdapterInterstitial: NSObject, AMInterstitialAdDelegate, GADCustomEventInterstitial {
    public var delegate: GADCustomEventInterstitialDelegate?
    
    var interstitialAd: AMInterstitialAd?
    
    public required override init() {
        
    }
    
    public func requestAd(withParameter serverParameter: String?, label serverLabel: String?, request: GADCustomEventRequest) {
        interstitialAd = AMInterstitialAd(placementId: serverParameter ?? "")
        interstitialAd?.delegate = self
        
        interstitialAd?.loadAd()
    }
    
    public func present(fromRootViewController rootViewController: UIViewController) {
        if !(interstitialAd?.isReady ?? false) {
            print("Could not display interstitial ad, no ad ready")
            return
        }
        print("AdMob mediation adapter interstitial show")
        delegate?.customEventInterstitialWillPresent(self)
        interstitialAd?.display(from: rootViewController)
    }
    
    public func adDidReceiveAd(_ ad: Any) {
        print("AdMob mediation adapter received ad")
        self.delegate?.customEventInterstitialDidReceiveAd(self)
    }
    
    public func ad(_ ad: Any, requestFailedWithError error: Error) {
        print("AdMob mediation adapter failed with error \(error.localizedDescription)")
        self.delegate?.customEventInterstitial(self, didFailAd: error)
    }
    
    public func adWasClicked(_ ad: Any) {
        self.delegate?.customEventInterstitialWasClicked(self)
    }
    
    public func adWillPresent(_ ad: Any) {
    }
    
    public func adWillClose(_ ad: Any) {
        self.delegate?.customEventInterstitialWillDismiss(self)
    }
    
    public func adDidClose(_ ad: Any) {
        self.delegate?.customEventInterstitialDidDismiss(self)
    }
    
    public func adWillLeaveApplication(_ ad: Any) {
        self.delegate?.customEventInterstitialWillLeaveApplication(self)
    }
    
}
