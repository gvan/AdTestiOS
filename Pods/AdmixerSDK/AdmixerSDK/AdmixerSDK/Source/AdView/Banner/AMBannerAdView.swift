//
//  AMBannerAdView.swift
//  AdmixerSDK
//
//  Created by admin on 09/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import UIKit



// MARK: - Local constants.
private let kAMInline = "inline"

@objc
public class AMBannerAdView: AMAdView {
    private var checkConfViewCounter: Int = 0
    private var _adSize = CGSize.zero
    public var adSize: CGSize {
        get {
            AMLogDebug("adSize returned \(_adSize)")
            return _adSize
        }
        set(adSize) {
            if adSize.equalTo(_adSize) {return}
            
            guard (adSize.width > 0) && (adSize.height > 0) else {
                AMLogError("Width and height of adSize must both be GREATER THAN ZERO.  (%@)", NSCoder.string(for: adSize))
                return
            }

            adSizes = [NSValue(cgSize: adSize)]

            AMLogDebug("Setting adSize to %@, NO smaller sizes.", NSCoder.string(for: adSize))
        }
    }
    private var _adSizes: [NSValue] = []
    @objc
    public var adSizes: [NSValue] {
        @objc
        get {_adSizes}
        @objc
        set(values) {
            let adSizeAsValue = values.first
            if adSizeAsValue == nil {
                AMLogError("adSizes array IS EMPTY.")
                return
            }

            for valueElement in values {
                let sizeElement = valueElement.cgSizeValue

                if (sizeElement.width <= 0) || (sizeElement.height <= 0) {
                    AMLogError("One or more elements of adSizes have a width or height LESS THAN ONE (1). \(values)")
                    return
                }
            }

            //
            _adSize = adSizeAsValue?.cgSizeValue ?? CGSize.zero
            _adSizes = values // copyItems: true
            allowSmallerSizes = false
        }
    }
    var     alignment: AMBannerViewAdAlignment?
    weak var appEventDelegate: AMAppEventDelegate?
    @objc
    public var     autoRefreshInterval: TimeInterval = 30.0
    var     enableNativeRendering = false
    private(set) var nativeAdRendererId = 0
    public weak var rootViewController: UIViewController?
    @objc
    public var loadedAdSize = CGSize.zero
    private var loadAdHasBeenInvoked = false
    @objc
    public var     shouldResizeAdToFitContainer = false
    private var     shouldAllowVideoDemand = false
    var     shouldAllowNativeDemand = false
    private var videoAdOrientation: AMVideoOrientation = .anUnknown
    private var impressionURLs: [String]?

    private var nativeAdResponse: AMNativeAdResponse?


    private var _contentView: UIView?
    internal var contentView: UIView? {
        get {
            _contentView
        }
        set(newContentView) {
            if newContentView != _contentView {
                let oldContentView = _contentView
                _contentView = newContentView

                if (newContentView is AMMRAIDContainerView) {
                    let adView = newContentView as? AMMRAIDContainerView
                    adView?.adViewDelegate = self
                }

                if (oldContentView is AMMRAIDContainerView) {
                    let adView = oldContentView as? AMMRAIDContainerView
                    adView?.adViewDelegate = nil
                }

                if (newContentView is AMNativeRenderingViewController) {
                    let adView = newContentView as? AMNativeRenderingViewController
                    adView?.adViewDelegate = self
                }

                if (oldContentView is AMNativeRenderingViewController) {
                    let adView = oldContentView as? AMNativeRenderingViewController
                    adView?.adViewDelegate = nil
                }

                performTransition(fromContentView: oldContentView, toContentView: newContentView)
            }
        }
    }
    

// MARK: - Lifecycle.
    public override func awakeFromNib() {
        super.awakeFromNib()
        autoresizingMask = []
        adSize = frame.size
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        adFormat = .banner
        autoresizingMask = []
        backgroundColor = UIColor.clear
    }
    
    @objc
    public convenience init(frame: CGRect, placementId: String) {
        self.init(frame: frame, placementId: placementId, adSize: frame.size)
    }

    @objc
    public convenience init(frame: CGRect, placementId: String, adSize size: CGSize) {
        self.init(frame: frame)

        adFormat = .banner
        self.adSize = size
        self.placementId = placementId
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc
    public override func loadAd() {
        loadAdHasBeenInvoked = true
        super.loadAd()
    }

// MARK: - Getter and Setter methods

    func getVideoOrientation() -> AMVideoOrientation {
        return videoAdOrientation
    }


    // adSize represents Universal Tag "primary_size".
    //
    func setAdSize(_ adSize: CGSize) {
        if adSize.equalTo(self.adSize) {
            return
        }

        if (adSize.width <= 0) || (adSize.height <= 0) {
            AMLogError("Width and height of adSize must both be GREATER THAN ZERO.  \(NSCoder.string(for: adSize))")
            return
        }

        //
        adSizes = [NSValue(cgSize: adSize)]

        AMLogDebug("Setting adSize to %@, NO smaller sizes.", NSCoder.string(for: adSize))
    }

    // adSizes represents Universal Tag "sizes".
    //
    func setAdSizes(_ adSizes: [NSValue]) {
        guard let adSizeAsValue = adSizes.first else {
            AMLogError("adSizes array IS EMPTY.")
            return
        }

        for valueElement in adSizes {
            let sizeElement = valueElement.cgSizeValue

            if (sizeElement.width <= 0) || (sizeElement.height <= 0) {
                AMLogError("One or more elements of adSizes have a width or height LESS THAN ONE (1). \(adSizes)")
                return
            }
        }

        self.adSize = adSizeAsValue.cgSizeValue
        self.adSizes = adSizes // copyItems: true
        allowSmallerSizes = false
    }

    // If auto refresh interval is above zero (0), enable auto refresh,
    // though never with a refresh interval value below kAMBannerMinimumAutoRefreshInterval.
    private var _autoRefreshInterval: TimeInterval = 0.0
    func setAutoRefreshInterval(_ autoRefreshInterval: TimeInterval) {
        if autoRefreshInterval <= kAMBannerAutoRefreshThreshold {
            _autoRefreshInterval = kAMBannerAutoRefreshThreshold
            AMLogDebug("Turning auto refresh off")

            return
        }

        if autoRefreshInterval < kAMBannerMinimumAutoRefreshInterval {
            _autoRefreshInterval = kAMBannerMinimumAutoRefreshInterval
            AMLogWarn(
                "setAutoRefreshInterval called with value \(autoRefreshInterval), autoRefreshInterval set to minimum allowed value \(kAMBannerMinimumAutoRefreshInterval).")
        } else {
            _autoRefreshInterval = autoRefreshInterval
            AMLogDebug("AutoRefresh interval set to \(_autoRefreshInterval) seconds")
        }


        //
        if loadAdHasBeenInvoked {
            loadAd()
        }
    }

// MARK: - Transitions

    public override func layoutSubviews() {
        super.layoutSubviews()

        if shouldResizeAdToFitContainer {
            let horizontalScaleFactor = frame.size.width / (contentView?.anOriginalFrame.size.width ?? 0.0)
            let verticalScaleFactor = frame.size.height / (contentView?.anOriginalFrame.size.height ?? 0.0)
            let scaleFactor = horizontalScaleFactor < verticalScaleFactor ? horizontalScaleFactor : verticalScaleFactor
            let transform = CGAffineTransform(scaleX: scaleFactor, y: scaleFactor)
            contentView?.transform = transform
        }
    }

// MARK: - Implementation of abstract methods from AMAdView
    override func loadAd(fromHtml html: String, width: Int, height: Int) {
        adSize = CGSize(width: CGFloat(width), height: CGFloat(height))
        super.loadAd(fromHtml: html, width: width, height: height)
    }

// MARK: - AMUniversalAdFetcherDelegate
    @objc override func universalAdFetcher(_ fetcher: AMUniversalAdFetcher?, didFinishRequestWith response: AMAdFetcherResponse?) {
        var error: Error?
        guard let response = response else { return }
        if response.successful {
            loadAdHasBeenInvoked = true

            guard let adObject = response.adObject else { return }
            guard let adObjectHandler = response.adObjectHandler else { return }
            contentView = nil
            impressionURLs = nil
            checkConfViewCounter = 0
             
            self.adResponseInfo = adObjectHandler.adResponseInfo
            self.creativeId = adObjectHandler.creativeId
            let adTypeString = adObjectHandler.adType
            self.adType = AMAdType.fromString(adTypeString ?? "")

            if (adObject is UIView) {

                contentView = adObject as? UIView
                let w = adObjectHandler.width
                let h = adObjectHandler.height

                if w != nil && h != nil {
                    loadedAdSize = CGSize(width: w ?? 0, height: h ?? 0)
                } else {
                    loadedAdSize = adSize
                }
                adDidReceiveAd(self)

                if adResponseInfo?.adType == .banner { //&& !(adObjectHandler is AMNativeStandardAdResponse) {

                    impressionURLs = adObjectHandler.impressionUrls
                    clickURLs = adObjectHandler.clickUrls
                    self.checkConfView()
                    if self.anExposedPercentage > 0 {
                        AMTrackerManager.fireTrackerURLArray(impressionURLs)
                        // Fire OMID - Impression event only for Admixer WKWebview TRUE for RTB and SSM
//                        if (contentView is AMMRAIDContainerView) {
//                            let standardAdView = contentView as? AMMRAIDContainerView
                            //                        if(standardAdView.webViewController.omidAdSession != nil){
                            //                            [[AMOMIDImplementation sharedInstance] fireOMIDImpressionOccuredEvent:standardAdView.webViewController.omidAdSession];
                            //                        }
//                        }
                    }
                }
            } else if (adObject is AMNativeAdResponse) {
                let nativeAdResponse = response.adObject as? AMNativeAdResponse

                self.creativeId = nativeAdResponse?.creativeId
                adType = AMAdType.native

                nativeAdResponse?.clickThroughAction = clickThroughAction
                nativeAdResponse?.landingPageLoadsInBackground = landingPageLoadsInBackground

                //
                ad(self, didReceiveNativeAd: nativeAdResponse)
            } else {
                let unrecognizedResponseErrorMessage = "UNRECOGNIZED ad response.  (\(type(of: adObject)))"

                let errorInfo = [
                    NSLocalizedDescriptionKey: NSLocalizedString(
                    unrecognizedResponseErrorMessage,
                    comment: "Error: UNKNOWN ad object returned as response to multi-format ad request.")
                ]

                error = NSError(domain: AM_ERROR_DOMAIN, code: AMAdResponseCode.amAdResponseNonViewResponse.rawValue, userInfo: errorInfo)
            }
        } else {
            error = response.error
        }


        if error != nil {
            contentView = nil
            adRequestFailedWithError(error, andAdResponseInfo: response.adResponseInfo)
        }
    }

    @objc func autoRefreshInterval(for fetcher: AMUniversalAdFetcher?) -> TimeInterval {
        return autoRefreshInterval
    }

    @objc override func requestedSize(for fetcher: AMUniversalAdFetcher?) -> CGSize {
        return adSize
    }

    @objc override func videoAdType(for fetcher: AMUniversalAdFetcher?) -> AMVideoAdSubtype {
        return .bannerVideo
    }

    override func internalDelegateUniversalTagSizeParameters() -> [AnyHashable : Any] {
        var containerSize = adSize

        if adSize.equalTo(ADMIXER_SIZE_UNDEFINED) {
            containerSize = frame.size
            adSizes = [NSValue(cgSize: containerSize)]
            allowSmallerSizes = true
        }

        //
        var dict: [AnyHashable : Any] = [:]
        dict[AMInternalDelgateTagKeyPrimarySize] = NSValue(cgSize: containerSize)
        dict[AMInternalDelegateTagKeySizes] = adSizes
        dict[AMInternalDelegateTagKeyAllowSmallerSizes] = NSNumber(value: allowSmallerSizes)

        return dict
    }

// MARK: - AMAdViewInternalDelegate
    override func adTypeForMRAID() -> String? {
        return kAMInline
    }

    func setAllowNativeDemand(
        _ nativeDemand: Bool,
        withRendererId rendererId: Int
    ) {
        nativeAdRendererId = rendererId
        shouldAllowNativeDemand = nativeDemand
    }

    override func adAllowedMediaTypes() -> [Int] {
        var mediaTypes: [AMAllowedMediaType] = []
        mediaTypes.append(.banner)
        if shouldAllowNativeDemand { mediaTypes.append(.native) }
        if shouldAllowVideoDemand { mediaTypes.append(.video) }
        return mediaTypes.map{$0.rawValue}
    }

    override func displayController() -> UIViewController? {
        var displayController = rootViewController

        if displayController == nil {
            displayController = anParentViewController
        }

        return displayController
    }

// MARK: - UIView observer methods.
    public override func didMoveToWindow() {
        if contentView != nil && (adResponseInfo?.adType == .banner) {
            AMTrackerManager.fireTrackerURLArray(impressionURLs)
        }
    }
    
    //MARK:- private
    private func checkConfView() {
        guard let urls = self.impressionURLs, urls.count > 0 else { return }
        
        checkConfViewCounter = self.anExposedPercentage >= 50  ? checkConfViewCounter + 1 : 0
        guard checkConfViewCounter == 2 else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {[weak self] in
                self?.checkConfView()
            }
            return
        }
        
        var confViewURLs: [String] = []
        
        for url in urls {
            guard url.contains("cet=4") else { continue }
            confViewURLs.append(url.replacingOccurrences(of: "cet=4", with: "cet=9"))
        }
        AMTrackerManager.fireTrackerURLArray(confViewURLs)
        
    }
}

