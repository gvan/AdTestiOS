//
//  AMAdAdapterRewardedAdMob.swift
//  GoogleMediation
//
//  Created by Admixer on 15.03.2021.
//

import AdmixerSDK
import GoogleMobileAds

public class AMAdAdapterRewardedAdMob: NSObject, AMCustomAdapterRewarded, GADFullScreenContentDelegate {
    
    
    required override public init() {
        
    }
    
    public var rewardedDelegate: (AMCustomAdapterRewardedDelegate)?
    
    public var delegate: AMCustomAdapterDelegate? {
        get {rewardedDelegate}
        set {rewardedDelegate = newValue as? AMCustomAdapterRewardedDelegate}
    }
    
    private var rewardedAd: GADRewardedAd?
    
    public func requestAd(withParameter paramenterString: String?, adUnitId idString: String?, targetingParameters: AMTargetingParameters?) {
        
        GADRewardedAd.load(withAdUnitID: idString!,
                           request: createRequest(from: targetingParameters)) { (ad, error) in
            if let error = error {
                AMLogDebug("AdMob rewarded failed to load with error: \(error.localizedDescription)")
                let code: AMAdResponseCode? = AMAdAdapterBase.parseErrorCode(from: error as NSError)
                self.delegate?.didFail(toLoadAd: code ?? .amAdResponseInternalError)
                return
            }
            
            AMLogDebug("AdMob rewarded did load")
            self.rewardedAd = ad
            self.rewardedAd?.fullScreenContentDelegate = self
            self.rewardedDelegate?.didLoadRewardedAd(self)
        }
        
    }
    
    func createRequest(from targetingParameters: AMTargetingParameters?) -> GADRequest? {
        return AMAdAdapterBase.googleAdRequest(from: targetingParameters)
    }
    
    public func present(from viewController: UIViewController?) {
        if let ad = rewardedAd {
            if let viewController = viewController {
                ad.present(fromRootViewController: viewController) {
                    let gadReward: GADAdReward? = self.rewardedAd?.adReward
                    let reward = AMRewardedItem(rewardType: gadReward?.type ?? "", rewardAmount: gadReward?.amount ?? 0)
                    self.rewardedDelegate?.adRewarded(reward)
                }
            }
        } else {
            AMLogDebug("Failed to present ad")
            rewardedDelegate?.failedToDisplayAd()
        }
    }
    
    public func isReady() -> Bool {
        return rewardedAd != nil
    }
    
    public func adDidPresentFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        delegate?.didPresentAd()
    }
    
    public func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        delegate?.didCloseAd()
    }
    
    public func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        AMLogDebug("AdMob rewarded failed to present with error: \(error.localizedDescription)")
        let code: AMAdResponseCode? = AMAdAdapterBase.parseErrorCode(from: error as NSError)
        self.delegate?.didFail(toLoadAd: code ?? .amAdResponseInternalError)
    }
    
    deinit {
        AMLogDebug("AdMob rewarded being destroyed")
        rewardedAd?.fullScreenContentDelegate = nil
        rewardedAd = nil
    }
    
}
