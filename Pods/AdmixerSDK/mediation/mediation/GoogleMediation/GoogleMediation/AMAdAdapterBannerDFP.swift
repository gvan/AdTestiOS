//
//  AMAdAdapterBannerDFP.swift
//  GoogleMediation
//
//  Created by Admixer on 29.01.2021.
//

import AdmixerSDK
import GoogleMobileAds

public class AMAdAdapterBannerDFP: NSObject, AMCustomAdapterBanner, GADBannerViewDelegate {
    
    required public override init() {
        
    }
    
    public var bannerDelegate: AMCustomAdapterBannerDelegate?
    
    public var delegate: AMCustomAdapterDelegate? {
        get {bannerDelegate}
        set {bannerDelegate = newValue as? AMCustomAdapterBannerDelegate}
    }
    
    private var bannerView: GAMBannerView?
    
    public func requestAd(with size: CGSize, rootViewController: UIViewController?, serverParameter parameterString: String?, adUnitId idString: String?, targetingParameters: AMTargetingParameters?) {
        var gadAdSize: GADAdSize
        if size.width == -1 && size.height == -2 {
            if UIDevice.current.orientation.isLandscape {
                gadAdSize = kGADAdSizeSmartBannerLandscape
            } else {
                gadAdSize = kGADAdSizeSmartBannerPortrait
            }
        } else {
            gadAdSize = GADAdSizeFromCGSize(size)
        }
        
        bannerView = GAMBannerView(adSize: gadAdSize)
        bannerView?.adUnitID = idString
        
        bannerView?.rootViewController = rootViewController
        bannerView?.delegate = self
        if let request = createRequest(from: targetingParameters) {
            bannerView?.load(request)
        }
    }
    
    func createRequest(from targetingParameters: AMTargetingParameters?) -> GAMRequest? {
        return AMAdAdapterBase.gamRequest(from: targetingParameters)
    }
    
    public func bannerViewDidReceiveAd(_ bannerView: GADBannerView) {
        AMLogDebug("DFP banner did load")
        bannerDelegate?.didLoadBannerAd(bannerView)
    }
    
    public func bannerView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: Error) {
        let errDescription = error.localizedDescription
        AMLogDebug("DFP banner failed to load with error: \(errDescription)")
        let code: AMAdResponseCode? = AMAdAdapterBase.parseErrorCode(from: error as NSError)
        delegate?.didFail(toLoadAd: code ?? .amAdResponseInternalError)
    }
    
    public func bannerViewWillPresentScreen(_ bannerView: GADBannerView) {
        delegate?.willPresentAd()
    }
    
    public func bannerViewWillDismissScreen(_ bannerView: GADBannerView) {
        delegate?.willCloseAd()
    }
    
    public func bannerViewDidDismissScreen(_ bannerView: GADBannerView) {
        delegate?.didCloseAd()
    }
    
    public func adViewWillLeaveApplication(_ bannerView: GADBannerView) {
        delegate?.adWasClicked()
    }
    
    deinit {
        AMLogDebug("DFP banner being destroyed")
        bannerView?.delegate = nil
        bannerView = nil
    }
    
}
