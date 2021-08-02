//
//  AMVideoPlayerSettings.swift
//  AdmixerSDK
//
//  Created by admin on 09/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import Foundation

enum AMInitialAudioSetting : Int {
    case soundOn
    case soundOff
    case `default`
}

//#import "AMOMIDImplementation.h"
let AMName = "name"
let AMVersion = "version"
let AMPartner = "partner"
let AMEntry = "entryPoint"
let AMInstreamVideo = "INSTREAM_VIDEO"
let AMBanner = "BANNER"
let AMAdText = "adText"
let AMSeparator = "separator"
let AMEnabled = "enabled"
let AMText = "text"
let AMLearnMore = "learnMore"
let AMMute = "setMute"
let AMAllowFullScreen = "allowFullscreen"
let AMShowFullScreen = "showFullScreenButton"
let AMDisableTopBar = "disableTopBar"
let AMVideoOptions = "videoOptions"
let AMInitialAudio = "initialAudio"
let AMOn = "on"
let AMOff = "off"
let AMSkip = "skippable"
let AMSkipDescription = "skipText"
let AMSkipText = "skipText"
let AMSkipLabelName = "skipButtonText"
let AMSkipOffset = "videoOffset"
let AMShowSkipButton = "showSkipButton"
let AMBackgroundColor = "backgroundColor"
let AMLearnMoreText = "learnMoreText"

/*
 The video player for the AdUnit (Instream & Outstream) can be configured by the publisher
 The available options that the publishers can change are the
 1. ClickThru Control changes
    1.1 Change the text for clickthru control
    1.2 Hide the control if not needed
    1.3 Remove or Change the "Ad" text
 2. Show/Hide volume control
 3. Show/Hide fullscreen control for outstream adUnit
 4. Show/Hide the topBar
 */
public class AMVideoPlayerSettings: NSObject {
    //Show or Hide the ClickThru control on the video player. Default is YES, setting it to NO will make the entire video clickable.
    public var showClickThruControl = true
    //Change the clickThru text on the video player
    var clickThruText: String?
    //Show or hide the "Ad" text next to the ClickThru control
    var showAdText = false
    //Change the ad text on the video player
    var adText: String?
    //Show or hide the volume control on the player
    public var showVolumeControl = true
    //Decide how the ad video sound starts initally (sound on or off). By default its on for InstreamVideo and off for Banner Video
    var initalAudio: AMInitialAudioSetting!
    //Show or hide fullscreen control on the player. This is applicable only for Banner Video
    var showFullScreenControl = false
    //Show or hide the top bar that has (ClickThru & Skip control)
    var showTopBar = false
    //Show or hide the Skip control on the player
    public var showSkip = true
    //Change the skip description on the video player
    var skipDescription: String?
    //Change the learn more label name on the video player
    public var learnMoreLabelName: String?
    //Change the skip label name on the video player
    public var skipLabelName: String?
    //Configure the skip offset on the video player
    var skipOffset = 0
    //Set the background color for non-instream player
    public var playerBackgroundColor: String?
    //Set the background color for instream player
    public var instreamBackgroundColor: String?

    public static let sharedInstance = AMVideoPlayerSettings()

    private var optionsDictionary: [String : Any] = [:]

    func videoPlayerOptions() -> String? {

        var publisherOptions: [String : Any] = [:]
        var clickthruOptions: [String : Any] = [:]
        
        if showAdText && adText != nil {
            publisherOptions[AMAdText] = adText ?? ""
        } else if showAdText == false {
            publisherOptions[AMAdText] = ""
            clickthruOptions[AMSeparator] = ""
        }
        clickthruOptions[AMEnabled] = NSNumber(value: showClickThruControl)

        if clickThruText != nil && showClickThruControl {
            clickthruOptions[AMText] = clickThruText ?? ""
        }

        publisherOptions[AMLearnMore] = clickthruOptions

        let entry = optionsDictionary[AMEntry] as? String
        if entry == AMInstreamVideo {
            var skipOptions: [String : Any] = [:]
            if showSkip {
                skipOptions[AMSkipDescription] = skipDescription ?? ""
                skipOptions[AMSkipLabelName] = skipLabelName ?? ""
                skipOptions[AMSkipOffset] = NSNumber(value: skipOffset)
            }
            skipOptions[AMEnabled] = NSNumber(value: showSkip)
            publisherOptions[AMSkip] = skipOptions
            publisherOptions[AMShowSkipButton] = showSkip
            if instreamBackgroundColor != nil {
                publisherOptions[AMBackgroundColor] = instreamBackgroundColor
            }
        }

        publisherOptions[AMMute] = NSNumber(value: showVolumeControl)

        if (entry == AMBanner) {
            publisherOptions[AMAllowFullScreen] = NSNumber(value: showFullScreenControl)
            publisherOptions[AMShowFullScreen] = NSNumber(value: showFullScreenControl)
            publisherOptions[AMShowSkipButton] = false
            if playerBackgroundColor != nil {
                publisherOptions[AMBackgroundColor] = playerBackgroundColor
            }
        }

        if initalAudio != .`default` {
            if initalAudio == .soundOn {
                publisherOptions[AMInitialAudio] = AMOn
            } else {
                publisherOptions[AMInitialAudio] = AMOff
            }
        } else {
            if publisherOptions[AMInitialAudio] != nil {
                publisherOptions[AMInitialAudio] = nil
            }
        }

        if !showTopBar {
            publisherOptions[AMDisableTopBar] = NSNumber(value: true)
        }
        
        if learnMoreLabelName != nil {
            publisherOptions[AMLearnMoreText] = learnMoreLabelName
        }
        
        if skipLabelName != nil {
            publisherOptions[AMSkipText] = skipLabelName
        }

        if publisherOptions.count > 0 {
            optionsDictionary[AMVideoOptions] = publisherOptions
        }
        
        var jsonData: Data? = nil
        do {
            jsonData = try JSONSerialization.data(withJSONObject: optionsDictionary, options: [])
            
        } catch {}
        
        if let jsonData = jsonData {
            return String(data: jsonData, encoding: .utf8)
        }
        return nil

    }

    func fetchInStreamVideoSettings() -> String? {
        optionsDictionary[AMEntry] = AMInstreamVideo
        return videoPlayerOptions()
    }

    func fetchBannerSettings() -> String? {
        optionsDictionary[AMEntry] = AMBanner
        return videoPlayerOptions()
    }
}
