//
//  AMInstreamVideoAd.swift
//  AdmixerSDK
//
//  Created by Admixer on 26.02.2021.
//  Copyright © 2021 Admixer. All rights reserved.
//

import AVFoundation
import Foundation
import UIKit

//----------------------------------------------------------
enum AMInstreamVideoPlaybackStateType : Int {
    case anInstreamVideoPlaybackStateError = -1
    case anInstreamVideoPlaybackStateCompleted = 0
    case anInstreamVideoPlaybackStateSkipped = 1
}

//----------------------------------------------------------
@objc public protocol AMInstreamVideoAdLoadDelegate: NSObjectProtocol {
    func adDidReceiveAd(_ ad: Any)

    @objc optional func ad(_ ad: Any, requestFailedWithError error: Error)
}

@objc public protocol AMInstreamVideoAdPlayDelegate: NSObjectProtocol {
    @objc optional func adDidComplete(
        _ ad: AMAdView
    )

    @objc optional func adCompletedFirstQuartile(_ ad: AMAdView)
    @objc optional func adCompletedMidQuartile(_ ad: AMAdView)
    @objc optional func adCompletedThirdQuartile(_ ad: AMAdView)
    @objc optional func adMute(
        _ ad: AMAdView,
        withStatus muteStatus: Bool
    )
    @objc optional func adWasClicked(_ ad: AMAdView)
    @objc optional func adWasClicked(_ ad: AMAdView, withURL urlString: String)
    @objc optional func adWillClose(_ ad: AMAdView)
    @objc optional func adDidClose(_ ad: AMAdView)
    @objc optional func adWillPresent(_ ad: AMAdView)
    @objc optional func adDidPresent(_ ad: AMAdView)
    @objc optional func adWillLeaveApplication(_ ad: AMAdView)
    @objc optional func adPlayStarted(_ ad: AMAdView)
}

//----------------------------------------------------------
public class AMInstreamVideoAd: AMAdView, AMVideoAdProtocol, AMVideoAdPlayerDelegate {
    // Public properties.
    //
    weak var loadDelegate: AMInstreamVideoAdLoadDelegate?
    private(set) weak var playDelegate: AMInstreamVideoAdPlayDelegate?
    private var adPlayer: AMVideoAdPlayer?
    private var adContainer: UIView?
    //
    private(set) var descriptionOfFailure: String?
    private(set) var failureNSError: Error?
    private(set) var didUserSkipAd = false
    private(set) var didUserClickAd = false
    private(set) var isAdMuted = false
    private(set) var isVideoTagReady = false
    private(set) var didVideoTagFail = false
    private(set) var isAdPlaying = false
    //
    private var _allowedAdSizes: Set<NSValue> = []
    var allowedAdSizes: Set<NSValue> {
        get {
            _allowedAdSizes
        }
        set(newValue) {
            if (newValue.count <= 0) {
                AMLogError("adSizes array IS EMPTY.")
                return
            }

            for value in newValue {
                let sizeElement = value.cgSizeValue

                if (sizeElement.width <= 0) || (sizeElement.height <= 0) {
                    AMLogError("One or more elements assigned to allowedAdSizes have a width or height LESS THAM ZERO. \(newValue)")
                    return
                }
            }

            _allowedAdSizes = Set(newValue)
        }
    }
    
    public override var frame: CGRect {
        get {
            let screenBounds = AMPortraitScreenBounds()
            if UIDevice.current.orientation.isLandscape {
                return CGRect(x: screenBounds.origin.y, y: screenBounds.origin.x, width: screenBounds.size.height, height: screenBounds.size.width)
            }
            return screenBounds;
        }
        set {
        }
    }
    private var containerSize = CGSize.zero

    // Lifecycle methods.
    //
    
    public init(placementId: String) {
        super.init(frame: CGRect(origin: CGPoint(x: 0, y: 0), size: CGSize(width: 300, height: 250)))
        
        isAdPlaying = false
        didUserSkipAd = false
        didUserClickAd = false
        isAdMuted = false
        isVideoTagReady = false
        didVideoTagFail = false

        clickThroughAction = .openSDKBrowser
        landingPageLoadsInBackground = true
        containerSize = CGSize.zero

        setupSizeParametersAs1x1()
        
        self.placementId = placementId
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupSizeParametersAs1x1() {
        self.allowedAdSizes = Set([NSValue(cgSize: kAMAdSize1x1)])
        allowSmallerSizes = false
    }

    public func loadAd(with loadDelegate: AMInstreamVideoAdLoadDelegate?) -> Bool {
        if loadDelegate == nil {
            AMLogWarn("loadDelegate is UNDEFINED.  AMInstreamVideoAdLoadDelegate allows detection of when a video ad is successfully received and loaded.")
        }

        self.loadDelegate = loadDelegate

        if universalAdFetcher != nil {

            universalAdFetcher?.requestAd()
        } else {
            AMLogError("FAILED TO FETCH video ad.")
            return false
        }

        return true
    }

    public func play(
        withContainer adContainer: UIView,
        with playDelegate: AMInstreamVideoAdPlayDelegate?
    ) {
        if playDelegate == nil {
            AMLogError("playDelegate is UNDEFINED.  AMInstreamVideoAdPlayDelegate allows the lifecycle of a video ad to be tracked, including when the video ad is completed.")
            return
        }

        self.playDelegate = playDelegate

        adPlayer?.playAd(withContainer: adContainer)
    }

    public func pauseAd() {
        if adPlayer != nil {
            adPlayer?.pauseAdVideo()
        }
    }

    public func resumeAd() {
        if adPlayer != nil {
            adPlayer?.resumeAdVideo()
        }
    }

    public func removeAd() {
        if adPlayer != nil {
            adPlayer?.remove()
            adPlayer?.removeFromSuperview()
            adPlayer?.delegate = nil
            adPlayer = nil
        }
    }
    
    public func hideClickThruControl() {
        adPlayer?.hideClickThruControl()
    }
    
    public func showClickThruControl() {
        adPlayer?.showClickTruControl()
    }
    
    public func hideVolumeControl() {
        adPlayer?.hideVolumeControl()
    }
    
    public func showVolumeControl() {
        adPlayer?.showVolumeControl()
    }
    
    public func hideSkip() {
        adPlayer?.hideSkip()
    }
    
    public func showSkip() {
        adPlayer?.showSkip()
    }

    func getDuration() -> Int {
        return adPlayer?.getAdDuration() ?? 0
    }

    func getCreativeURL() -> String? {
        return adPlayer?.getCreativeURL()
    }

    func getVastURL() -> String? {
        return adPlayer?.getVASTURL()
    }

    func getVastXML() -> String? {
        return adPlayer?.getVASTXML()
    }
    
    func getVideoOrientation() -> AMVideoOrientation {
        return (adPlayer?.getVideoAdOrientation())!
    }

    func getPlayElapsedTime() -> Int {
        return adPlayer?.getAdPlayElapsedTime() ?? 0
    }
    
    public func getCreativeWidth() -> Int? {
        return adPlayer?.getCreativeWidth()
    }
    
    public func getCreativeHeight() -> Int? {
        return adPlayer?.getCreativeHeight()
    }
    
    // MARK: - AMVideoAdPlayerDelegate.
        @objc func videoAdReady() {
            self.isVideoTagReady = true

            if self.loadDelegate?.responds(to: #selector(self.adDidReceiveAd(_:))) ?? false {
                self.loadDelegate?.adDidReceiveAd(self)
            }
        }

        @objc func videoAdLoadFailed(_ error: Error, with adResponseInfo: AMAdResponseInfo?) {
            didVideoTagFail = true

            descriptionOfFailure = nil
            failureNSError = error

            self.adResponseInfo = adResponseInfo

            AMLogError("Delegate indicates FAILURE.")
            removeAd()

            if loadDelegate?.responds(to: #selector(AMInstreamVideoAdLoadDelegate.ad(_:requestFailedWithError:))) ?? false {
                if let failureNSError = failureNSError {
                    loadDelegate?.ad!(self, requestFailedWithError: failureNSError)
                }
            }
        }

        @objc func videoAdPlayFailed(_ error: Error?) {
            didVideoTagFail = true

            if playDelegate?.responds(to: #selector(AMInstreamVideoAdPlayDelegate.adDidComplete(_:))) ?? false {
                playDelegate?.adDidComplete!(self)
            }

            removeAd()
        }

        @objc func videoAdError(_ error: Error) {
            descriptionOfFailure = nil
            failureNSError = error

            if playDelegate?.responds(to: #selector(AMInstreamVideoAdPlayDelegate.adDidComplete(_:))) ?? false {
                playDelegate?.adDidComplete!(self)
            }
        }

        @objc func videoAdWillPresent(_ videoAd: AMVideoAdPlayer) {
            pauseAd()
            if playDelegate?.responds(to: #selector(AMInstreamVideoAdPlayDelegate.adWillPresent(_:))) ?? false {
                playDelegate?.adWillPresent?(self)
            }
        }

        @objc func videoAdDidPresent(_ videoAd: AMVideoAdPlayer) {
            if playDelegate?.responds(to: #selector(AMInstreamVideoAdPlayDelegate.adDidPresent(_:))) ?? false {
                playDelegate?.adDidPresent?(self)
            }
        }

        @objc func videoAdWillClose(_ videoAd: AMVideoAdPlayer) {
            if playDelegate?.responds(to: #selector(AMInstreamVideoAdPlayDelegate.adWillClose(_:))) ?? false {
                playDelegate?.adWillClose?(self)
            }
        }

        func videoAdDidClose(_ videoAd: AMVideoAdPlayer) {
            resumeAd()
            if playDelegate?.responds(to: #selector(AMInstreamVideoAdPlayDelegate.adDidClose(_:))) ?? false {
                playDelegate?.adDidClose?(self)
            }
        }

        @objc func videoAdWillLeaveApplication(_ videoAd: AMVideoAdPlayer) {
            if playDelegate?.responds(to: #selector(AMInstreamVideoAdPlayDelegate.adWillLeaveApplication(_:))) ?? false {
                playDelegate?.adWillLeaveApplication?(self)
            }
        }

        @objc func videoAdImpressionListeners(_ tracker: AMVideoAdPlayerTracker) {
            switch tracker {
                case .firstQuartile:
                    if playDelegate?.responds(to: #selector(AMInstreamVideoAdPlayDelegate.adCompletedFirstQuartile(_:))) ?? false {
                        playDelegate?.adCompletedFirstQuartile?(self)
                    }
                case .midQuartile:
                    if playDelegate?.responds(to: #selector(AMInstreamVideoAdPlayDelegate.adCompletedMidQuartile(_:))) ?? false {
                        playDelegate?.adCompletedMidQuartile?(self)
                    }
                case .thirdQuartile:
                    if playDelegate?.responds(to: #selector(AMInstreamVideoAdPlayDelegate.adCompletedThirdQuartile(_:))) ?? false {
                        playDelegate?.adCompletedThirdQuartile?(self)
                    }
                case .fourthQuartile:
                    if playDelegate?.responds(to: #selector(AMInstreamVideoAdPlayDelegate.adDidComplete(_:))) ?? false {
                        removeAd()
                        playDelegate?.adDidComplete!(self)
                    }
                default:
                    break
            }
        }

        @objc func videoAdEventListeners(_ eventTrackers: AMVideoAdPlayerEvent) {
            switch eventTrackers {
                case .play:
                    isAdPlaying = true
                    if playDelegate?.responds(to: #selector(AMInstreamVideoAdPlayDelegate.adPlayStarted(_:))) ?? false {
                        playDelegate?.adPlayStarted?(self)
                    }
                case .skip:
                    didUserSkipAd = true
                    if playDelegate?.responds(to: #selector(AMInstreamVideoAdPlayDelegate.adDidComplete(_:))) ?? false {
                        removeAd()
                        playDelegate?.adDidComplete!(self)
                    }
                case .muteOn:
                    isAdMuted = true
                    if playDelegate?.responds(to: #selector(AMInstreamVideoAdPlayDelegate.adMute(_:withStatus:))) ?? false {
                        playDelegate?.adMute?(self, withStatus: isAdMuted)
                    }
                case .muteOff:
                    isAdMuted = false
                    if playDelegate?.responds(to: #selector(AMInstreamVideoAdPlayDelegate.adMute(_:withStatus:))) ?? false {
                        playDelegate?.adMute?(self, withStatus: isAdMuted)
                    }
                default:
                    break
            }
        }

        @objc func videoAdWasClicked() {
            didUserClickAd = true

            if playDelegate?.responds(to: #selector(AMInstreamVideoAdPlayDelegate.adWasClicked(_:))) ?? false {
                playDelegate?.adWasClicked?(self)
            }
        }

        @objc func videoAdWasClicked(withURL urlString: String) {
            didUserClickAd = true

            if playDelegate?.responds(to: #selector(AMInstreamVideoAdPlayDelegate.adWasClicked(_:withURL:))) ?? false {
                playDelegate?.adWasClicked?(self, withURL: urlString)
            }
        }

        @objc func videoAdPlayerLandingPageLoadsInBackground() -> Bool {
            return landingPageLoadsInBackground
        }

        @objc func videoAdPlayerClickThroughAction() -> AMClickThroughAction {
            return clickThroughAction
        }
    
    // MARK: - AMUniversalAdFetcherDelegate.
    @objc override func universalAdFetcher( _ fetcher: AMUniversalAdFetcher?, didFinishRequestWith response: AMAdFetcherResponse?) {
            guard let response = response else { return }
            
            if (response.adObject is AMVideoAdPlayer) {
                adPlayer = response.adObject as? AMVideoAdPlayer
                adPlayer?.delegate = self
                
                let handler = response.adObjectHandler

                if let adResponseInfo = handler?.adResponseInfo {
                    self.adResponseInfo = adResponseInfo
                }

                if let creativeId = handler?.creativeId {
                    self.creativeId = creativeId
                }

                videoAdReady()
            } else if !(response.successful ?? false) && (response.adObject == nil) {
                videoAdLoadFailed(AMError("video_adfetch_failed", AMAdResponseCode.amAdResponseBadFormat.rawValue), with: response.adResponseInfo)
                return
            }
        }

    override func adAllowedMediaTypes() -> [Int] {
            return [AMAllowedMediaType.video.rawValue]
        }

    override func internalDelegateUniversalTagSizeParameters() -> [AnyHashable : Any] {
            containerSize = frame.size
            
            var allowedAdSizesForSDK = Set<NSValue>(allowedAdSizes)
            allowedAdSizesForSDK.insert(NSValue(cgSize: kAMAdSize1x1))
            allowedAdSizesForSDK.insert(NSValue(cgSize: containerSize))
            
            allowSmallerSizes = false
            
            var delegateReturnDictionary: [AnyHashable : Any] = [:]
            delegateReturnDictionary[AMInternalDelgateTagKeyPrimarySize] = NSValue(cgSize: containerSize)
            delegateReturnDictionary[AMInternalDelegateTagKeySizes] = Array(allowedAdSizesForSDK)
            delegateReturnDictionary[AMInternalDelegateTagKeyAllowSmallerSizes] = NSNumber(value: allowSmallerSizes)

            return delegateReturnDictionary
        }

    @objc override func videoAdType(for fetcher: AMUniversalAdFetcher?) -> AMVideoAdSubtype {
            return .instream
        }
    
    // MARK: - AMAdProtocol.

        /// Set the user's current location.  This allows ad buyers to do location targeting, which can increase spend.
    public override func setLocationWithLatitude(
            _ latitude: CGFloat,
            longitude: CGFloat,
            timestamp: Date?,
            horizontalAccuracy: CGFloat
        ) {
            location = AMLocation.getWithLatitude(
                latitude,
                longitude: longitude,
                timestamp: timestamp,
                horizontalAccuracy: horizontalAccuracy)
        }

        /// Set the user's current location rounded to the number of decimal places specified in "precision".
        /// Valid values are between 0 and 6 inclusive. If the precision is -1, no rounding will occur.
    public override func setLocationWithLatitude(
            _ latitude: CGFloat,
            longitude: CGFloat,
            timestamp: Date?,
            horizontalAccuracy: CGFloat,
            precision: Int
        ) {
            location = AMLocation.getWithLatitude(
                latitude,
                longitude: longitude,
                timestamp: timestamp,
                horizontalAccuracy: horizontalAccuracy,
                precision: precision)
        }
}
