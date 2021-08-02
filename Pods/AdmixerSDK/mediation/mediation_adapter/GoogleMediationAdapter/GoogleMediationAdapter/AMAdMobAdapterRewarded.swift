//
//  AMAdMobAdapterRewarded.swift
//  GoogleMediationAdapter
//
//  Created by Admixer on 22.03.2021.
//

import AdmixerSDK
import GoogleMobileAds

public class AMAdMobAdapterRewarded: NSObject, AMRewardedAdDelegate, GADMediationAdapter, GADMediationRewardedAd {
    
    public required override init() {
        
    }
    
    private var rewardedAd: AMRewardedAd? = nil
    private var completionHandler: GADMediationRewardedLoadCompletionHandler?
    private var adEventDelegate: GADMediationRewardedAdEventDelegate?
    
    // MARK: GADMediationAdapter
    
    public func loadRewardedAd(for adConfiguration: GADMediationRewardedAdConfiguration,
                               completionHandler: @escaping GADMediationRewardedLoadCompletionHandler) {
        self.completionHandler = completionHandler
        
        let adUnitId: String = adConfiguration.credentials.settings["parameter"] as! String
        
        self.rewardedAd = AMRewardedAd(placementId: adUnitId)
        self.rewardedAd?.clickThroughAction = .openSDKBrowser
        self.rewardedAd?.delegate = self
        self.rewardedAd?.loadAd()
    }
    
    public static func adapterVersion() -> GADVersionNumber {
        return GADVersionNumber(majorVersion: 0, minorVersion: 0, patchVersion: 0)
    }
    
    public static func adSDKVersion() -> GADVersionNumber {
        return GADVersionNumber(majorVersion: 0, minorVersion: 0, patchVersion: 0)
    }
    
    public static func networkExtrasClass() -> GADAdNetworkExtras.Type? {
        return nil
    }
    
    // MARK: GADMediationRewardedAd
    
    public func present(from viewController: UIViewController) {
        if let rewardedAd = self.rewardedAd {
            rewardedAd.display(from: viewController)
        }
    }
    
    // MARK: AMRewardedAdDelegate
    
    public func adDidReceiveAd(_ ad: Any) {
        AMLogDebug("Ad did received")
        if let completionHandler = completionHandler {
            self.adEventDelegate = completionHandler(self, nil)
        }
    }
    
    public func ad(_ ad: Any, requestFailedWithError error: Error) {
        if let completionHandler = completionHandler {
            self.adEventDelegate = completionHandler(nil, error)
        }
    }
    
    public func adWasClicked(_ ad: Any) {
        if let adEventDelegate = adEventDelegate {
            adEventDelegate.reportClick()
        }
    }
    
    public func adWasClicked(_ ad: AMAdView, withURL urlString: String) {
        if let adEventDelegate = adEventDelegate {
            adEventDelegate.reportClick()
        }
    }
    
    public func adWillPresent(_ ad: Any) {
        if let adEventDelegate = adEventDelegate {
            adEventDelegate.willPresentFullScreenView()
        }
    }
    
    public func adDidClose(_ ad: Any) {
        if let adEventDelegate = adEventDelegate {
            adEventDelegate.didDismissFullScreenView()
        }
    }
    
    public func adRewarded(_ ad: AMRewardedAd, userDidEarn reward: AMRewardedItem) {
        if let adEventDelegate = adEventDelegate {
            let reward = GADAdReward(rewardType: reward.type, rewardAmount: reward.amount)
            adEventDelegate.didRewardUser(with: reward)
        }
    }
    
}
