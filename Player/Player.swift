//
//  Player.swift
//  Player
//
//  Created by Fredrik Sjöberg on 2017-04-04.
//  Copyright © 2017 emp. All rights reserved.
//

import Foundation
import AVFoundation
import Exposure

public final class Player {
    
    fileprivate var avPlayer: AVPlayer
    fileprivate var currentAsset: MediaAsset?
    
    public init() {
        avPlayer = AVPlayer()
        
        playerObserver.observe(path: .currentItem, on: avPlayer) { [unowned self] player, change in
            print("Player.currentItem changed",player, change.new)
        }
        
        // Observe BitRate changes
        playerObserver.subscribe(notification: .AVPlayerItemNewAccessLogEntry, for: avPlayer) { [unowned self] notification in
            if let item = notification.object as? AVPlayerItem, let accessLog = item.accessLog() {
                if let currentEvent = accessLog.events.last {
                    let previousIndex = accessLog
                        .events
                        .index(of: currentEvent)?
                        .advanced(by: -1)
                    let previousEvent = previousIndex != nil ? accessLog.events[previousIndex!] : nil
                    let event = BitrateChangedEvent(player: self,
                                                    previousRate: previousEvent?.indicatedBitrate,
                                                    currentRate: currentEvent.indicatedBitrate)
                    self.onBitrateChanged(event)
                }
            }
        }
    }
    
    deinit {
        playerObserver.stopObservingAll()
    }
    
    /*
     Periodic Observer: AVPlayer
     
     open func addPeriodicTimeObserver(forInterval interval: CMTime, queue: DispatchQueue?, using block: @escaping (CMTime) -> Swift.Void) -> Any
     open func addBoundaryTimeObserver(forTimes times: [NSValue], queue: DispatchQueue?, using block: @escaping () -> Swift.Void) -> Any
     open func removeTimeObserver(_ observer: Any)
    */
    
    // MARK: PlayerEventPublisher
    fileprivate var onCreated: (Player) -> Void = { _ in }
    fileprivate var onInitCompleted: (Player) -> Void = { _ in }
    fileprivate var onPlaybackReady: (Player) -> Void = { _ in }
    fileprivate var onError: (Player, PlayerError) -> Void = { _ in }
    fileprivate var onPlaybackCompleted: (Player) -> Void = { _ in }
    fileprivate var onBitrateChanged: (BitrateChangedEvent) -> Void = { _ in }
    fileprivate var onPlaybackStarted: (Player) -> Void = { _ in }
    fileprivate var onPlaybackAborted: (Player) -> Void = { _ in }
    fileprivate var onPlaybackPaused: (Player) -> Void = { _ in }
    fileprivate var onPlaybackResumed: (Player) -> Void = { _ in }
    
    /*// MARK: Change Observation
    lazy fileprivate var itemObserver: PlayerItemObserver = { [unowned self] in
        return PlayerItemObserver()
    }()*/
    
    lazy fileprivate var playerObserver: PlayerObserver = { [unowned self] in
        return PlayerObserver()
    }()
    
    // MARK: MediaPlayback
    fileprivate var playbackState: PlaybackState = .notStarted
}

// MARK: - PlayerEventPublisher
extension Player: PlayerEventPublisher {
    public typealias PlayerEventError = PlayerError
    
    
    // MARK: Lifecycle
    @discardableResult
    public func onCreated(callback: @escaping (Player) -> Void) -> Self {
        onCreated = callback
        return self
    }
    
    @discardableResult
    public func onInitCompleted(callback: @escaping (Player) -> Void) -> Self {
        onInitCompleted = callback
        return self
    }
    
    @discardableResult
    public func onPlaybackReady(callback: @escaping (Player) -> Void) -> Self {
        onPlaybackReady = callback
        return self
    }
    
    @discardableResult
    public func onPlaybackCompleted(callback: @escaping (Player) -> Void) -> Self {
        onPlaybackCompleted = callback
        return self
    }
    
    @discardableResult
    public func onError(callback: @escaping (Player, PlayerError) -> Void) -> Self {
        onError = callback
        return self
    }
    
    
    // MARK: Configuration
    @discardableResult
    public func onBitrateChanged(callback: @escaping (BitrateChangedEvent) -> Void) -> Self {
        onBitrateChanged = callback
        return self
    }
    
    // MARK: Actions
    @discardableResult
    public func onPlaybackStarted(callback: @escaping (Player) -> Void) -> Self {
        onPlaybackStarted = callback
        return self
    }
    
    @discardableResult
    public func onPlaybackAborted(callback: @escaping (Player) -> Void) -> Self {
        onPlaybackAborted = callback
        return self
    }
    
    @discardableResult
    public func onPlaybackPaused(callback: @escaping (Player) -> Void) -> Self {
        onPlaybackPaused = callback
        return self
    }
    
    @discardableResult
    public func onPlaybackResumed(callback: @escaping (Player) -> Void) -> Self {
        onPlaybackResumed = callback
        return self
    }
    
}

// MARK: - MediaRendering
extension Player: MediaRendering {
    public func configure(playerView: UIView) {
        let renderingView = PlayerView(frame: playerView.frame)
        
        renderingView.avPlayerLayer.player = avPlayer
        renderingView.avPlayerLayer.videoGravity = AVLayerVideoGravityResizeAspect
        renderingView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        playerView.addSubview(renderingView)
        
        renderingView
            .leadingAnchor
            .constraint(equalTo: playerView.leadingAnchor)
            .isActive = true
        renderingView
            .topAnchor
            .constraint(equalTo: playerView.topAnchor)
            .isActive = true
        renderingView
            .rightAnchor
            .constraint(equalTo: playerView.rightAnchor)
            .isActive = true
        renderingView
            .bottomAnchor
            .constraint(equalTo: playerView.bottomAnchor)
            .isActive = true
    }
}

// MARK: - MediaPlayback
extension Player: MediaPlayback {
    fileprivate enum PlaybackState {
        case notStarted
        case playing
        case paused
    }
    
    public func play() {
        switch playbackState {
        case .notStarted:
            avPlayer.play()
            playbackState = .playing
            onPlaybackStarted(self)
        case .paused:
            avPlayer.play()
            onPlaybackResumed(self)
            playbackState = .playing
        default:
            return
        }
    }
    
    public func pause() {
        guard isPlaying else { return }
        avPlayer.pause()
        playbackState = .paused
        onPlaybackPaused(self)
    }
    
    public func stop() {
        // TODO: End playback? Unload resources? Leave that to user?
        avPlayer.pause()
        playbackState = .paused
        onPlaybackAborted(self)
    }
    
    public var isPlaying: Bool {
        return avPlayer.rate != 0
    }
}


// MARK: - Playback
extension Player {
    public func stream(url mediaLocator: String, using fairplayRequester: FairplayRequester) {
        do {
            currentAsset = try MediaAsset(mediaLocator: mediaLocator, fairplayRequester: fairplayRequester)
            onCreated(self)
            
            currentAsset?.prepare(loading: [.duration, .tracks, .playable]) { [unowned self] error in
                guard error == nil else {
                    self.onError(self, error!)
                    return
                }
                
                self.onInitCompleted(self)
                
                self.readyPlayback(with: self.currentAsset!)
            }
        }
        catch {
            if let playerError = error as? PlayerError {
                onError(self, playerError)
            }
            else {
                onError(self, PlayerError.generalError(error: error))
            }
        }
    }
    
    fileprivate func readyPlayback(with mediaAsset: MediaAsset) {
        // Unsubscribe any current item
        currentAsset?.itemObserver.stopObservingAll()
        currentAsset?.itemObserver.unsubscribeAll()
        
        currentAsset = mediaAsset
        
        let playerItem = mediaAsset.playerItem
        
        // Observe changes to .status for new playerItem
        mediaAsset.itemObserver.observe(path: .status, on: playerItem) { [unowned self] item, change in
            if let newValue = change.new as? Int, let status = AVPlayerItemStatus(rawValue: newValue) {
                switch status {
                case .unknown:
                    // TODO: Do we send anything on .unknown?
                    return
                case .readyToPlay:
                    if item != nil {
                        // We only send playbackReady if we have a non-nil asset attached that is ready to play.
                        self.onPlaybackReady(self)
                    }
                case .failed:
                    self.onError(self, .asset(reason: .failedToReady(error: item.error)))
                }
            }
        }
        
        // ADITIONAL KVO TO CONSIDER
        //[_currentItem removeObserver:self forKeyPath:@"loadedTimeRanges"]; // availableDuration?
        //[_currentItem removeObserver:self forKeyPath:@"playbackBufferEmpty"]; // BUFFERING
        //[_currentItem removeObserver:self forKeyPath:@"playbackLikelyToKeepUp"]; // PLAYREADY?
        
        
        // Observe when currentItem has played to the end
        mediaAsset.itemObserver.subscribe(notification: .AVPlayerItemDidPlayToEndTime, for: playerItem) { [unowned self] notification in
            self.onPlaybackCompleted(self)
        }
        
        // Update AVPlayer by replacing old AVPlayerItem with newly created currentItem
        if let currentlyPlaying = avPlayer.currentItem, currentlyPlaying == playerItem {
            // NOTE: Make surewe dont replace an item with the same item
            // TODO: Should this perhaps be done before we actully try replacing and unsub/sub KVO/notifications
            return
        }
        
        // Replace the player item with a new player item. The item replacement occurs
        // asynchronously; observe the currentItem property to find out when the
        // replacement will/did occur
        avPlayer.replaceCurrentItem(with: playerItem)
    }
}
