//
//  AMAdMobAdapterBanner.swift
//  GoogleMediationAdapter
//
//  Created by Admixer on 29.01.2021.
//

import AdmixerSDK
import GoogleMobileAds

public class AMAdMobAdapterBanner: NSObject, AMBannerAdViewDelegate, GADCustomEventBanner {
    public var delegate: GADCustomEventBannerDelegate?
    
    var bannerAdView: AMBannerAdView?
    
    public required override init() {
        
    }
    
    public func requestAd(_ adSize: GADAdSize, parameter serverParameter: String?, label serverLabel: String?, request: GADCustomEventRequest) {
        let frame: CGRect
        frame = CGRect(x: 0, y: 0, width: adSize.size.width, height: adSize.size.height)
        bannerAdView = AMBannerAdView(frame: frame, placementId: serverParameter ?? "", adSize: adSize.size)
        bannerAdView?.delegate = self
        bannerAdView?.rootViewController = UIApplication.shared.delegate?.window??.rootViewController
        bannerAdView?.clickThroughAction = .openDeviceBrowser
        bannerAdView?.autoRefreshInterval = 0
        
        bannerAdView?.loadAd()
    }
    
    public func adDidReceiveAd(_ ad: Any) {
        print("AdMob mediation adapter banner loaded")
        delegate?.customEventBanner(self, didReceiveAd: (ad as? AMBannerAdView)!)
    }
    
    public func ad(_ ad: Any, requestFailedWithError error: Error) {
        print("AdMob mediation adapter failed with error \(error.localizedDescription)")
        self.delegate?.customEventBanner(self, didFailAd: error)
    }
    
    public func adWasClicked(_ ad: Any) {
        self.delegate?.customEventBannerWasClicked(self)
    }
    
    public func adWillPresent(_ ad: Any) {
        self.delegate?.customEventBannerWillPresentModal(self)
    }
    
    public func adWillClose(_ ad: Any) {
        self.delegate?.customEventBannerWillDismissModal(self)
    }
    
    public func adDidClose(_ ad: Any) {
        self.delegate?.customEventBannerDidDismissModal(self)
    }
    
    public func adWillLeaveApplication(_ ad: Any) {
        self.delegate?.customEventBannerWillLeaveApplication(self)
    }
    
}
