//
//  AMAdView.swift
//  AdmixerSDK
//
//  Created by admin on 09/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import UIKit

let DEFAULT_PUBLIC_SERVICE_ANNOUNCEMENT = false

open class AMAdView: UIView, AMUniversalTagRequestBuilderFetcherDelegate {
    var allowSmallerSizes = false
    var minDuration: Int = 0
    
    var maxDuration: Int = 0
    
    public var memberId: Int = 0
    public var publisherId : Int = 0
    public var location: AMLocation?
    public var age: String?
    public var gender: AMGender = .unknown
    public var externalUid: String?
    public var contentId: String?
    public var ortbObject: Data?
    
    var placementId: String?
    var inventoryCode: String?
    var reserve: CGFloat = 0
    var adType: AMAdType = .banner
    var adFormat: AMAdFormat = .unknown
    
    public var clickThroughAction: AMClickThroughAction = .openSDKBrowser
    var landingPageLoadsInBackground: Bool = true
    
    public var creativeId: String?
    var adResponseInfo: AMAdResponseInfo?
    var clickURLs: [String]? = nil
    
    public var shouldServePublicServiceAnnouncements: Bool = DEFAULT_PUBLIC_SERVICE_ANNOUNCEMENT
    
    var customKeywords: [String : [String]]? = [:]
    
    @objc
    public weak var delegate: AMAdDelegate?
    private weak var appEventDelegate: AMAppEventDelegate?

    private var _universalAdFetcher: AMUniversalAdFetcher?
    var universalAdFetcher: AMUniversalAdFetcher? {
        if _universalAdFetcher != nil {
            return _universalAdFetcher
        }

        if marManager != nil {
            if let marManager = marManager {
                _universalAdFetcher = AMUniversalAdFetcher(delegate: self, andAdUnitMultiAdRequestManager: marManager)
            }
        } else {
            _universalAdFetcher = AMUniversalAdFetcher(delegate: self)
        }

        return _universalAdFetcher
    }

    private weak var _marManager: AMMultiAdRequest?
    private weak var marManager: AMMultiAdRequest? {
        get {
            _marManager
        }
        set(marManager) {

            _marManager = marManager
        }
    }
    private var utRequestUUIDString = anUUID

// MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.clipsToBounds = true
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    //NB  Any entry point that requires awakeFromNib must locally set the size parameters: adSize, adSizes, allowSmallerSizes.
    //
    public override func awakeFromNib() {
        super.awakeFromNib()
        self.clipsToBounds = true
    }

    deinit {
        AMLogDebug("%@", utRequestUUIDString) //DEBUG
        NotificationCenter.default.removeObserver(self)

        if universalAdFetcher != nil {
            universalAdFetcher?.stopAdLoad()
        }
    }

    func errorCheckConfiguration() -> Bool {
        var errorString: String = ""
        var errorInfo: [String : String]? = nil
        var error: Error? = nil
        var code: Int

        //
        
        let placementIdValid = (placementId?.count ?? 0) >= 1
        let inventoryCodeValid = (memberId >= 1) && inventoryCode != nil


        if !placementIdValid && !inventoryCodeValid {
            errorString = AMErrorString("no_placement_id")
            errorInfo = [NSLocalizedDescriptionKey : errorString]
            code = AMAdResponseCode.amAdResponseInvalidRequest.rawValue
            error = NSError(domain: AM_ERROR_DOMAIN, code: code, userInfo: errorInfo)
        }

        if let banner = self as? AMBannerAdView {
            if banner.adSizes.isEmpty {
                errorString = AMErrorString("adSizes_undefined")
                errorInfo = [NSLocalizedDescriptionKey : errorString]
                code = AMAdResponseCode.amAdResponseInvalidRequest.rawValue
                error = NSError(domain: AM_ERROR_DOMAIN, code: code, userInfo: errorInfo)
            }
        }


        //
        if error != nil {
            AMLogError("\(errorString)")
            adRequestFailedWithError(error, andAdResponseInfo: nil)

            return false
        }

        return true
    }

    @objc
    public func loadAd() {
        if !errorCheckConfiguration() {
            return
        }

        //
        universalAdFetcher?.stopAdLoad()
        universalAdFetcher?.requestAd()

        if universalAdFetcher == nil {
            AMLogError("Fetcher is unallocated.  FAILED TO FETCH ad via UT.")
        }
    }

    func loadAd(fromHtml html: String, width: Int, height: Int) {
        guard let standardAd = AMUniversalTagAdServerResponse.generateStandardAdUnit(fromHTMLContent: html, width: width, height: height) else { return }

        var adsArray: [AMBaseAdObject] = [standardAd]

        self.universalAdFetcher?.beginWaterfall(withAdObjects: &adsArray)
    }

    func loadAd(fromVast xml: String, width: Int, height: Int) {
        guard let rtbVideoAd = AMUniversalTagAdServerResponse.generateRTBVideoAdUnit(fromVASTObject: xml, width: width, height: height) else { return }

        var adsArray: [AMBaseAdObject] = [rtbVideoAd]

        self.universalAdFetcher?.beginWaterfall(withAdObjects: &adsArray)
    }

    ///  This method provides a single point of entry for the MAR object to pass tag content received in the UT Request to the fetcher defined by the adunit.
    ///  Adding this public method which is used only for an internal process is more desirable than making the universalAdFetcher property public.
    func ingestAdResponseTag(_ tag: AMResponseTag?) {
        universalAdFetcher?.prepareForWaterfall(withAdServerResponseTag: tag)
    }
    
    private func fireClickTrackers() {
        guard clickURLs != nil else {return}
        
        AMTrackerManager.fireTrackerURLArray(clickURLs)
        clickURLs = nil
    }

// MARK: - AMUniversalAdFetcherDelegate
    @objc func enableNativeRendering() -> Bool {
        AMLogDebug("ABSTRACT METHOD -- Implement in Banner adunit")
        return false
    }

    

    
}

extension AMAdView : AMAdProtocol {
    public func setLocationWithLatitude(_ latitude: CGFloat, longitude: CGFloat, timestamp: Date?, horizontalAccuracy: CGFloat) {
        location = AMLocation.getWithLatitude(
            latitude,
            longitude: longitude,
            timestamp: timestamp,
            horizontalAccuracy: horizontalAccuracy)
    }

    public func setLocationWithLatitude(_ latitude: CGFloat, longitude: CGFloat, timestamp: Date?, horizontalAccuracy: CGFloat, precision: Int) {
        location = AMLocation.getWithLatitude(
            latitude,
            longitude: longitude,
            timestamp: timestamp,
            horizontalAccuracy: horizontalAccuracy,
            precision: precision)
    }
    
    public func addCustomKeyword(withKey key: String, value: String) {
        if key.isEmpty { return }
        guard var valueArray = customKeywords?[key] else {
            customKeywords?[key] = [value]
            return
        }
        
        if valueArray.contains(value) { return }
        valueArray.append(value)
        customKeywords?[key] = valueArray
    }
    
    public func removeCustomKeyword(withKey key: String) {
        if key.isEmpty { return }
        self.customKeywords?[key] = nil
    }
    
    public func clearCustomKeywords() {
        self.customKeywords?.removeAll()
    }
    
    func setInventoryCode(_ newInvCode: String?, memberId newMemberId: Int) {
        let newInvCode = newInvCode
        if (newMemberId > 0) && self.marManager != nil {
            guard marManager?.memberId == newMemberId else { return }
        }
        
        if let newInvCode = newInvCode {
            self.inventoryCode = newInvCode
        }
        
        guard newMemberId > 0 && newMemberId != self.memberId else { return }
        AMLogDebug("Setting member id to \(newMemberId)")
        self.memberId = newMemberId
    }
}

extension AMAdView : AMUniversalAdFetcherDelegate {
    
    func requestedSize(for fetcher: AMUniversalAdFetcher) -> CGSize {
        AMLogError("ABSTRACT METHOD -- Implement in each adunit.")
        return CGSize(width: -1, height: -1)
    }
    
    func adAllowedMediaTypes() -> [Int] {
        AMLogError("ABSTRACT METHOD -- Implement in each adunit.")
        return []
    }
    
    func internalDelegateUniversalTagSizeParameters() -> [AnyHashable : Any] {
        AMLogError("ABSTRACT METHOD -- Implement in each adunit.")
        return [:]
    }
    
    func internalGetUTRequestUUIDString() -> String {
        return utRequestUUIDString
    }
    
    func internalUTRequestUUIDStringReset() {
        self.utRequestUUIDString = anUUID
    }
    
    @objc func videoAdType(for fetcher: AMUniversalAdFetcher) -> AMVideoAdSubtype {
        AMLogWarn("ABSTRACT METHOD -- Implement in each adunit.")
        return .unknown
    }
    
    @objc func nativeAdRendererId() -> Int {
        AMLogDebug("ABSTRACT METHOD -- Implement in Banner and Native adunit")
        return 0
    }
    
    @objc func universalAdFetcher(_ fetcher: AMUniversalAdFetcher, didFinishRequestWith response: AMAdFetcherResponse) {
        AMLogError("ABSTRACT METHOD -- Implement in each adunit.")
    }
    
    @objc func adRewarded(_ rewardedItem: AMRewardedItem) {
        
    }
    
    @objc func getAdFormat() -> AMAdFormat {
        return self.adFormat
    }
    
}

extension AMAdView : AMAdViewInternalDelegate {
    func adRequestFailedWithError(_ error: Error?, andAdResponseInfo adResponseInfo: AMAdResponseInfo?) {
        self.adResponseInfo = adResponseInfo

        guard let error = error else { return }
        self.delegate?.ad?(self, requestFailedWithError: error)

    }
    
    func adWasClicked() {
        self.delegate?.adWasClicked?(self)
        if clickURLs != nil && clickURLs?.count ?? 0 > 0 {
            fireClickTrackers()
        }
    }

    func adWillPresent() {
        self.delegate?.adWillPresent?(self)
    }

    func adDidPresent() {
        self.delegate?.adDidPresent?(self)
    }
    
    func adWillClose() {
        self.delegate?.adWillClose?(self)
    }

    func adDidClose() {
         self.delegate?.adDidClose?(self)
    }

    func adWillLeaveApplication() {
        self.delegate?.adWillLeaveApplication?(self)
    }
    
    func adDidReceiveAppEvent(_ name: String?, withData data: String?) {
        appEventDelegate?.ad(self, didReceiveAppEvent: name ?? "", withData: data ?? "")
    }
    
    func adTypeForMRAID() -> String? {
        AMLogDebug("ABSTRACT METHOD.  MUST be implemented by subclass.")
        return ""
    }

    func displayController() -> UIViewController? {
        AMLogDebug("ABSTRACT METHOD.  MUST be implemented by subclass.")
        return nil
    }
    
    func adInteractionDidBegin() {
        AMLogDebug("")
        universalAdFetcher?.stopAdLoad()
    }

    func adInteractionDidEnd() {
        AMLogDebug("")
        guard let adResponseAdType = self.adResponseInfo?.adType else {return}
        if adResponseAdType == .video { return }
        
        universalAdFetcher?.restartAutoRefreshTimer()
        universalAdFetcher?.startAutoRefreshTimer()
    }
    //optional
    
    @objc func adWasClicked(withURL urlString: String?) {
        let urlString = urlString ?? ""
        self.delegate?.adWasClicked?(self, withURL: urlString)
    }
    
    @objc func adDidReceiveAd(_ adObject: Any?) {
        guard let adObject = adObject else { return }
        self.delegate?.adDidReceiveAd?(adObject)
    }
    
    @objc func ad(_ loadInstance: Any?, didReceiveNativeAd responseInstance: Any?) {
        guard let loadInstance = loadInstance, let responseInstance = responseInstance else { return }
        delegate?.ad?(loadInstance, didReceiveNativeAd: responseInstance)
    }
}
