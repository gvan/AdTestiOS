//
//  ViewController.swift
//  BannerTestStoryboard
//
//  Created by Ivan Ganzha on 14.01.2021.
//  Copyright © 2021 Ivan Ganzha. All rights reserved.
//

import UIKit
import AdmixerSDK
import GoogleMobileAds

class ViewController: UIViewController, AMRewardedAdDelegate  {
    
    private var interstitialAd: AMInterstitialAd?
//    private var adMobInterstitial: GADInterstitialAd?
    private var instream : AMInstreamVideoAd?
    private var rewardedAd: AMRewardedAd?

    override func viewDidLoad() {
        super.viewDidLoad()
//        checkCode()
        //        initClass()
        showBanner()
//        showInterstitial()
//        showRewarded()
//        showInstream()
//        showAdMobBanner()
//        showAdMobInterstitial()
        
        AMLogLevel.currentLevel = .all
    }
    
    private func checkCode(){
        let arr: [String] = []
        if arr.count > 0 {
            print("MyCustomLog not emtpy")
        } else {
            print("MyCustomLog empty")
        }
    }
    
    private func initClass(){
        guard
//            let adapterClass = NSClassFromString("AdmixerSDK.AMAdAdapterBannerAdMob")
            let adapterClass = NSClassFromString("AdmixerSDK.AMAdMobAdapterBanner")
        else {
            print("Init class failed")
            return
        }
        print("Init class success")
    }
    
    private func showBanner(){
        let adSize = CGSize(width: 300, height: 250)
        // Banner
//        let placementId = "f9a26255-08a2-40ec-9667-3ab35e69625a"
        // AdMob mediation
//        let placementId = "9d4a1ea4-8097-4c74-a1ca-bf30698bfe2b"
        // GAM mediation
//        let placementId = "c10d261d-de4a-4f78-895f-f2dee92828a9"
        // OpenSooq
        let placementId = "9533EE5C-C592-404D-8C37-1F2ED206B6A6"
        
        let startPoint = CGPoint(x: 0, y: 25)
        let bannerSize = CGSize(width: 300, height: 250)
        let bannerRect = CGRect(origin: startPoint, size: bannerSize)
        
        let banner = AMBannerAdView(frame: bannerRect, placementId: placementId, adSize: adSize)
        banner.autoRefreshInterval = 0
        banner.rootViewController = self
        
//        let jsonString = """
//        {
//        "app":{
//        "cat":["IAB14"]
//        }
//        }
//        """
//        banner.ortbObject = Data(jsonString.utf8)
        
        self.view.addSubview(banner)
        
        banner.loadAd()
    }
    
    private func showInterstitial(){
        // fullscreen
//        let placementId = "e94817ae-5d00-4d2a-98d7-5e9600f55ad6"
        // AdMob mediation
//        let placementId = "d0f2c0d2-ea84-41e0-bf5d-f1b1990189ef"
        // GAM mediation
        let placementId = "ef302082-1ffb-4e04-bbda-319e37ce4b63"
        let interstitialAd = AMInterstitialAd(placementId: placementId)
        interstitialAd.delegate = self
        interstitialAd.loadAd();

        self.interstitialAd = interstitialAd
        
    }
    
    private func showRewarded(){
//        let placementId = "f9a26255-08a2-40ec-9667-3ab35e69625a"
        let placementId = "c744a785-272b-4b85-8a93-5eb581d74565"
        rewardedAd = AMRewardedAd(placementId: placementId)
        rewardedAd?.delegate = self
        rewardedAd?.loadAd()
    }
    
    private func showInstream(){
        
//        AMVideoPlayerSettings.sharedInstance.learnMoreLabelName = "Hello my friend"
//        AMVideoPlayerSettings.sharedInstance.skipLabelName = "Go ahead"
        
        AMVideoPlayerSettings.sharedInstance.showClickThruControl = true
        AMVideoPlayerSettings.sharedInstance.showVolumeControl = true
        AMVideoPlayerSettings.sharedInstance.showSkip = true
        
        instream = AMInstreamVideoAd(placementId: "c744a785-272b-4b85-8a93-5eb581d74565");
        instream?.contentId = "123456789"
        instream?.loadAd(with: self);
    }
    
    private func showAdMobBanner(){
        let adSize = CGSize(width: 300, height: 250)
        let bannerSize = CGSize(width: 300, height: 250)
        let bannerOrigin = CGPoint(x: 0, y: 20)
        let bannerRect = CGRect(origin: bannerOrigin, size: bannerSize)
        let gadSize = GADAdSizeFromCGSize(adSize)
        let banner = GADBannerView(adSize: gadSize, origin: bannerOrigin)
        banner.frame = bannerRect
        // AdMob test
//        banner.adUnitID = "ca-app-pub-3940256099942544/6300978111"
        // AdMob mediate Admixer
        banner.adUnitID = "ca-app-pub-7975908713270977/6068367093"
        banner.rootViewController = self
        self.view.addSubview(banner)
        
        banner.load(GADRequest())
    }
    
    private func showAdMobInterstitial(){
//        GADInterstitialAd.load(withAdUnitID: "ca-app-pub-7975908713270977/7872381271", request: GADRequest()) { (ad, error) in
//
//        }
    }
    
    //  AMInterstitialAdDelegate
    //
    
    func adDidReceiveAd(_ ad: Any) {
        self.interstitialAd?.display(from: self)
        
        self.rewardedAd?.display(from: self)
        
        self.instream?.play(withContainer: self.view, with: self)
    }

}

extension ViewController : AMInstreamVideoAdLoadDelegate {
    func ad(_ loadInstance: Any, didReceiveNativeAd responseInstance: Any) {
        
    }
}

extension ViewController : AMInstreamVideoAdPlayDelegate {
    
}

