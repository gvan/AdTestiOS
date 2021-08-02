//
//  AMTrackerManager.swift
//  AdmixerSDK
//
//  Created by admin on 09/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import Foundation

private let kAMTrackerManagerMaximumNumberOfRetries = 3
private let kAMTrackerManagerRetryInterval: TimeInterval = 300

class AMTrackerManager: NSObject {
    static let shared = AMTrackerManager()

    class func fireTrackerURLArray(_ arrayWithURLs: [String]?) {
        self.shared.fireTrackerURLArray(arrayWithURLs)
    }

    class func fireTrackerURL(_ URL: String?) {
        self.shared.fireTrackerURL(URL)
    }

    private var trackerArray: [AMTrackerInfo] = []
    private var internetReachability: AMReachability?

    private var internetIsReachable: Bool {
        guard let reachability = self.internetReachability else { return false}
        let connection = reachability.connection
        let connectionRequired = reachability.flags?.isReachableFlagSet ?? false
        
        if connection == .unavailable && connectionRequired { return false}

        return true
    }
    private var trackerRetryTimer: Timer?

// MARK: - Lifecycle.

    override init() {
        super.init()
            internetReachability = AMReachability.shared
    }

// MARK: - Getters and Setters.

// MARK: - Public methods.

// MARK: - Private methods.
    func fireTrackerURLArray(_ arrayWithURLs: [String]?) {
        guard let arrayWithURLs = arrayWithURLs else { return}

        guard internetIsReachable else {
            AMLogDebug("Internet IS UNREACHABLE - queing trackers for firing later: \(arrayWithURLs)")
            arrayWithURLs.forEach{ self.queueTrackerURL(forRetry: $0) }
            return
        }
        //
        AMLogDebug("Internet is reachable - FIRING TRACKERS \(arrayWithURLs)")
        for urlString in arrayWithURLs {
            guard let url = URL(string: urlString) else { continue }
            let task = URLSession.shared.dataTask(with: AMBasicRequestWithURL(url), completionHandler: {[weak self] data, response, error in
                if error == nil { return }
                
                AMLogDebug("Internet REACHABILITY ERROR - queing tracker for firing later: %@", urlString)
                self?.queueTrackerURL(forRetry: urlString)
            })
            task.resume()
        }
    }

    func fireTrackerURL(_ urlString: String?) {
        guard let urlString = urlString else { return }
        if urlString.isEmpty { return }
        fireTrackerURLArray([urlString])
    }

    func retryTrackerFires() {
        var trackerArrayCopy: [AMTrackerInfo]?

        let lockQueue = DispatchQueue(label: "self")
        lockQueue.sync {
            if trackerArray.isEmpty { return }
            guard internetIsReachable else { return }
            
            AMLogDebug("Internet back online - Firing trackers \(trackerArray)")
            trackerArrayCopy = trackerArray
            trackerArray.removeAll()
            trackerRetryTimer?.invalidate()
            
        }
        
        trackerArrayCopy?.forEach{info in
            if info.expired { return }
            let urlString = info.url ?? ""
            guard let url = URL(string: urlString) else { return }
            let task = URLSession.shared.dataTask(with: AMBasicRequestWithURL(url)) { data, response, error in
                if error == nil {
                    AMLogDebug("RETRY SUCCESSFUL for \(info)")
                }
                
                AMLogDebug("CONNECTION ERROR - queing tracker for firing later: %@", info.url ?? "")
                info.numberOfTimesFired += 1

                if (info.numberOfTimesFired < kAMTrackerManagerMaximumNumberOfRetries) && !info.expired {
                    self.queueTrackerInfo(forRetry: info)
                }
            }
                
            task.resume()
        }
        
    }

    func queueTrackerURL(forRetry URL: String?) {
        queueTrackerInfo(forRetry: AMTrackerInfo(url: URL))
    }

    func queueTrackerInfo(forRetry trackerInfo: AMTrackerInfo?) {
        guard let trackerInfo = trackerInfo else { return }
        
        trackerArray.append(trackerInfo)
        let lockQueue = DispatchQueue(label: "self")
        lockQueue.sync {
            scheduleRetryTimerIfNecessary()
        }
        
    }

    func scheduleRetryTimerIfNecessary() {
        let isScheduled = trackerRetryTimer?.anIsScheduled()
        let needScedule = !(isScheduled ?? false)
        guard needScedule else { return }
            
        trackerRetryTimer = Timer.anScheduledTimer(with: kAMTrackerManagerRetryInterval, block: { [weak self] in
            guard let strongSelf = self else {
                AMLogError("FAILED TO ACQUIRE strongSelf.")
                return
            }
                    
            strongSelf.retryTrackerFires()
        },
        repeats: true)
        
    }
}
